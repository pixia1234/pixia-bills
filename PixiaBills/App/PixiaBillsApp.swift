import SwiftUI

@main
struct PixiaBillsApp: App {
    @StateObject private var store: BillsStore
    @StateObject private var settings: AppSettings
    @StateObject private var lockManager: BiometricLockManager

    init() {
        let appSettings = AppSettings()
        _settings = StateObject(wrappedValue: appSettings)
        _store = StateObject(wrappedValue: BillsStore())
        _lockManager = StateObject(wrappedValue: BiometricLockManager(isEnabled: appSettings.biometricLockEnabled))
    }

    var body: some Scene {
        WindowGroup {
            AppContainerView()
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(lockManager)
        }
    }
}
