import Foundation
import LocalAuthentication

public enum KeychainAuthenticator {
    /// GUI gate before reading or displaying a stored secret.
    public static func authenticateForSecretAccess() async throws {
        if ProcessInfo.processInfo.environment["LOADOUT_SKIP_PARTITION"] == "1" {
            return
        }

        let context = LAContext()
        context.localizedReason = "Authenticate to view this secret"
        context.localizedFallbackTitle = "Use Password"

        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            try KeychainAccess.unlockLoginKeychain()
            return
        }

        let success = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
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

        let context = LAContext()
        context.localizedReason = "Authorize loadout to update Keychain access"
        context.localizedFallbackTitle = "Use Password"

        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            try KeychainAccess.unlockLoginKeychain()
            return
        }

        var success = false
        var evaluationError: Error?
        let semaphore = DispatchSemaphore(value: 0)

        let evaluate = {
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Authorize loadout to fix Keychain access"
            ) { ok, error in
                success = ok
                evaluationError = error
                semaphore.signal()
            }
        }

        if Thread.isMainThread {
            evaluate()
        } else {
            DispatchQueue.main.sync(execute: evaluate)
        }

        semaphore.wait()

        if success {
            return
        }

        if let evaluationError {
            throw LoadoutError.io("authentication failed: \(evaluationError.localizedDescription)")
        }

        try KeychainAccess.unlockLoginKeychain()
    }
}