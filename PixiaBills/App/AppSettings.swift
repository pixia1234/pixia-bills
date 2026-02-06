import Foundation

@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let iCloudSyncEnabled = "settings.icloud.sync.enabled"
        static let biometricLockEnabled = "settings.biometric.lock.enabled"
        static let llmAPIBase = "settings.llm.api_base"
        static let llmAPIKey = "settings.llm.api_key"
        static let llmModel = "settings.llm.model"
    }

    private let defaults: UserDefaults

    @Published var iCloudSyncEnabled: Bool {
        didSet { defaults.set(iCloudSyncEnabled, forKey: Keys.iCloudSyncEnabled) }
    }

    @Published var biometricLockEnabled: Bool {
        didSet { defaults.set(biometricLockEnabled, forKey: Keys.biometricLockEnabled) }
    }

    @Published var llmAPIBase: String {
        didSet { defaults.set(llmAPIBase, forKey: Keys.llmAPIBase) }
    }

    @Published var llmAPIKey: String {
        didSet { defaults.set(llmAPIKey, forKey: Keys.llmAPIKey) }
    }

    @Published var llmModel: String {
        didSet { defaults.set(llmModel, forKey: Keys.llmModel) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        iCloudSyncEnabled = defaults.object(forKey: Keys.iCloudSyncEnabled) as? Bool ?? false
        biometricLockEnabled = defaults.object(forKey: Keys.biometricLockEnabled) as? Bool ?? false
        llmAPIBase = defaults.string(forKey: Keys.llmAPIBase) ?? "https://api.openai.com"
        llmAPIKey = defaults.string(forKey: Keys.llmAPIKey) ?? ""
        llmModel = defaults.string(forKey: Keys.llmModel) ?? "gpt-4o-mini"
    }
}
