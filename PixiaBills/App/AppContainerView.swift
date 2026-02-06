import SwiftUI

struct AppContainerView: View {
    @EnvironmentObject private var store: BillsStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var lockManager: BiometricLockManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            RootView()
                .disabled(lockManager.isLocked)
                .blur(radius: lockManager.isLocked ? 3 : 0)

            if lockManager.isLocked {
                LockOverlayView(
                    isAuthenticating: lockManager.isAuthenticating,
                    message: lockManager.errorMessage,
                    unlockAction: {
                        Task {
                            await lockManager.unlockIfNeeded()
                        }
                    }
                )
            }
        }
        .task {
            store.setICloudSyncEnabled(settings.iCloudSyncEnabled)
            lockManager.setEnabled(settings.biometricLockEnabled)
            if settings.biometricLockEnabled {
                await lockManager.unlockIfNeeded()
            }
        }
        .onChange(of: settings.iCloudSyncEnabled) { enabled in
            store.setICloudSyncEnabled(enabled)
        }
        .onChange(of: settings.biometricLockEnabled) { enabled in
            lockManager.setEnabled(enabled)
            if enabled {
                Task {
                    await lockManager.unlockIfNeeded()
                }
            }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                Task {
                    await lockManager.unlockIfNeeded()
                }
            case .inactive, .background:
                lockManager.appMovedToBackground()
            @unknown default:
                break
            }
        }
    }
}

private struct LockOverlayView: View {
    let isAuthenticating: Bool
    let message: String?
    let unlockAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(.primary)

            Text("账本已锁定")
                .font(.headline)

            if let message, !message.isEmpty {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                unlockAction()
            } label: {
                if isAuthenticating {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("解锁", systemImage: "faceid")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAuthenticating)
        }
        .padding(24)
        .frame(maxWidth: 360)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(24)
    }
}
