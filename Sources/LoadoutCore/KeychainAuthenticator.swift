import Foundation
import LocalAuthentication

enum KeychainAuthenticator {
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