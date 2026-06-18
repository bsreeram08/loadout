import Foundation
import LocalAuthentication

public enum KeychainAuthenticator {
    /// GUI gate before reading or displaying a stored secret.
    public static func authenticateForSecretAccess() async throws {
        if ProcessInfo.processInfo.environment["LOADOUT_SKIP_PARTITION"] == "1" {
            return
        }

        let needsPasswordFallback = try await evaluateBiometrics()
        if needsPasswordFallback {
            try await Task.detached(priority: .userInitiated) {
                try KeychainAccess.unlockLoginKeychain()
            }.value
        }
    }

    public static func isUserCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == LAError.errorDomain
            && (nsError.code == LAError.userCancel.rawValue
                || nsError.code == LAError.appCancel.rawValue
                || nsError.code == LAError.systemCancel.rawValue)
    }

    static func authenticateForRepair() throws {
        if ProcessInfo.processInfo.environment["LOADOUT_SKIP_PARTITION"] == "1" {
            return
        }

        let needsPasswordFallback = try runOnMainActorSync {
            try evaluateBiometricsSync()
        }

        if needsPasswordFallback {
            try KeychainAccess.unlockLoginKeychain()
        }
    }

    @MainActor
    private static func evaluateBiometrics() async throws -> Bool {
        let context = LAContext()
        context.localizedReason = "Authenticate to view this secret"
        context.localizedFallbackTitle = "Use Password"

        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            return true
        }

        let success: Bool = try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Authenticate to view this secret"
            ) { ok, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ok)
                }
            }
        }

        guard success else {
            throw LoadoutError.io("authentication cancelled")
        }

        return false
    }

    @MainActor
    private static func evaluateBiometricsSync() throws -> Bool {
        let context = LAContext()
        context.localizedReason = "Authorize loadout to update Keychain access"
        context.localizedFallbackTitle = "Use Password"

        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            return true
        }

        var success = false
        var evaluationError: Error?
        let semaphore = DispatchSemaphore(value: 0)

        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Authorize loadout to fix Keychain access"
        ) { ok, error in
            success = ok
            evaluationError = error
            semaphore.signal()
        }

        while semaphore.wait(timeout: .now()) == .timedOut {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }

        if let evaluationError {
            throw evaluationError
        }

        guard success else {
            throw LoadoutError.io("authentication failed")
        }

        return false
    }

    private static func runOnMainActorSync<T>(_ body: @MainActor @escaping () throws -> T) throws -> T {
        if Thread.isMainThread {
            return try MainActor.assumeIsolated(body)
        }

        var result: Result<T, Error>?
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            do {
                result = .success(try MainActor.assumeIsolated(body))
            } catch {
                result = .failure(error)
            }
            semaphore.signal()
        }
        semaphore.wait()
        return try result!.get()
    }
}