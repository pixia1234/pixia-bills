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
            store.updateWebDAVConfiguration(settings.webDAVConfiguration)
            store.setICloudSyncEnabled(settings.webDAVSyncEnabled)

            lockManager.setEnabled(settings.biometricLockEnabled)
            if settings.biometricLockEnabled {
                await lockManager.unlockIfNeeded()
            }
        }
        .onChange(of: settings.webDAVSyncEnabled) { enabled in
            store.updateWebDAVConfiguration(settings.webDAVConfiguration)
            store.setICloudSyncEnabled(enabled)
            if enabled {
                store.requestAutoWebDAVSync(trigger: "开启同步")
            }
        }
        .onChange(of: settings.webDAVScheme) { _ in
            refreshWebDAVConfigurationAndScheduleSync(trigger: "配置变更")
        }
        .onChange(of: settings.webDAVHost) { _ in
            refreshWebDAVConfigurationAndScheduleSync(trigger: "配置变更")
        }
        .onChange(of: settings.webDAVPort) { _ in
            refreshWebDAVConfigurationAndScheduleSync(trigger: "配置变更")
        }
        .onChange(of: settings.webDAVPath) { _ in
            refreshWebDAVConfigurationAndScheduleSync(trigger: "配置变更")
        }
        .onChange(of: settings.webDAVUsername) { _ in
            refreshWebDAVConfigurationAndScheduleSync(trigger: "配置变更")
        }
        .onChange(of: settings.webDAVPassword) { _ in
            refreshWebDAVConfigurationAndScheduleSync(trigger: "配置变更")
        }
        .onChange(of: settings.webDAVEncryptionKey) { _ in
            refreshWebDAVConfigurationAndScheduleSync(trigger: "配置变更")
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
                store.requestAutoWebDAVSync(trigger: "应用回到前台", debounceNanoseconds: 100_000_000)
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

    private func refreshWebDAVConfigurationAndScheduleSync(trigger: String) {
        store.updateWebDAVConfiguration(settings.webDAVConfiguration)
        guard settings.webDAVSyncEnabled else { return }
        store.requestAutoWebDAVSync(trigger: trigger, debounceNanoseconds: 300_000_000)
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
