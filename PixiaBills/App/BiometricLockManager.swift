import Foundation
import LocalAuthentication

@MainActor
final class BiometricLockManager: ObservableObject {
    @Published private(set) var isLocked: Bool
    @Published private(set) var isAuthenticating: Bool = false
    @Published var errorMessage: String?

    private var isEnabled: Bool

    init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
        self.isLocked = isEnabled
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            isLocked = false
            errorMessage = nil
        } else {
            isLocked = true
        }
    }

    func appMovedToBackground() {
        guard isEnabled else { return }
        isLocked = true
    }

    func unlockIfNeeded() async {
        guard isEnabled else {
            isLocked = false
            return
        }
        guard isLocked else { return }
        guard !isAuthenticating else { return }

        isAuthenticating = true
        defer { isAuthenticating = false }

        let context = LAContext()
        context.localizedFallbackTitle = "使用设备密码"

        var evaluateError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &evaluateError) else {
            errorMessage = evaluateError?.localizedDescription ?? "当前设备无法使用 Face ID / Touch ID"
            isLocked = false
            return
        }

        let success = await evaluateDeviceOwnerAuthentication(context: context)
        if success {
            isLocked = false
            errorMessage = nil
        }
    }

    private func evaluateDeviceOwnerAuthentication(context: LAContext) async -> Bool {
        await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "解锁 pixia-bills"
            ) { success, error in
                Task { @MainActor in
                    if !success {
                        self.errorMessage = error?.localizedDescription ?? "验证失败，请重试"
                    }
                    continuation.resume(returning: success)
                }
            }
        }
    }
}
