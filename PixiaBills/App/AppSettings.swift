import Foundation

@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let legacyICloudSyncEnabled = "settings.icloud.sync.enabled"
        static let webDAVSyncEnabled = "settings.webdav.sync.enabled"
        static let webDAVScheme = "settings.webdav.scheme"
        static let webDAVHost = "settings.webdav.host"
        static let webDAVPort = "settings.webdav.port"
        static let webDAVPath = "settings.webdav.path"
        static let webDAVUsername = "settings.webdav.username"
        static let webDAVPassword = "settings.webdav.password"
        static let webDAVEncryptionKey = "settings.webdav.encryption_key"

        static let biometricLockEnabled = "settings.biometric.lock.enabled"
        static let llmAPIBase = "settings.llm.api_base"
        static let llmAPIKey = "settings.llm.api_key"
        static let llmModel = "settings.llm.model"
    }

    private let defaults: UserDefaults

    @Published var webDAVSyncEnabled: Bool {
        didSet { defaults.set(webDAVSyncEnabled, forKey: Keys.webDAVSyncEnabled) }
    }

    @Published var webDAVScheme: String {
        didSet { defaults.set(webDAVScheme, forKey: Keys.webDAVScheme) }
    }

    @Published var webDAVHost: String {
        didSet { defaults.set(webDAVHost, forKey: Keys.webDAVHost) }
    }

    @Published var webDAVPort: String {
        didSet { defaults.set(webDAVPort, forKey: Keys.webDAVPort) }
    }

    @Published var webDAVPath: String {
        didSet { defaults.set(webDAVPath, forKey: Keys.webDAVPath) }
    }

    @Published var webDAVUsername: String {
        didSet { defaults.set(webDAVUsername, forKey: Keys.webDAVUsername) }
    }

    @Published var webDAVPassword: String {
        didSet { defaults.set(webDAVPassword, forKey: Keys.webDAVPassword) }
    }

    @Published var webDAVEncryptionKey: String {
        didSet { defaults.set(webDAVEncryptionKey, forKey: Keys.webDAVEncryptionKey) }
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

    var webDAVConfiguration: WebDAVSyncConfiguration {
        WebDAVSyncConfiguration(
            scheme: webDAVScheme,
            host: webDAVHost,
            port: webDAVPort,
            path: webDAVPath,
            username: webDAVUsername,
            password: webDAVPassword,
            encryptionKey: webDAVEncryptionKey
        )
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let legacyEnabled = defaults.object(forKey: Keys.legacyICloudSyncEnabled) as? Bool ?? false
        webDAVSyncEnabled = defaults.object(forKey: Keys.webDAVSyncEnabled) as? Bool ?? legacyEnabled

        webDAVScheme = defaults.string(forKey: Keys.webDAVScheme) ?? "https"
        webDAVHost = defaults.string(forKey: Keys.webDAVHost) ?? ""
        webDAVPort = defaults.string(forKey: Keys.webDAVPort) ?? ""
        webDAVPath = defaults.string(forKey: Keys.webDAVPath) ?? "/pixia-bills"
        webDAVUsername = defaults.string(forKey: Keys.webDAVUsername) ?? ""
        webDAVPassword = defaults.string(forKey: Keys.webDAVPassword) ?? ""
        webDAVEncryptionKey = defaults.string(forKey: Keys.webDAVEncryptionKey) ?? ""

        biometricLockEnabled = defaults.object(forKey: Keys.biometricLockEnabled) as? Bool ?? false
        llmAPIBase = defaults.string(forKey: Keys.llmAPIBase) ?? "https://api.openai.com"
        llmAPIKey = defaults.string(forKey: Keys.llmAPIKey) ?? ""
        llmModel = defaults.string(forKey: Keys.llmModel) ?? "gpt-4o-mini"
    }
}
