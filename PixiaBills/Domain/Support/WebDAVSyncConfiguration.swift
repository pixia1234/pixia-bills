import Foundation

struct WebDAVSyncConfiguration: Equatable {
    var scheme: String = "https"
    var host: String = ""
    var port: String = ""
    var path: String = "/pixia-bills"
    var username: String = ""
    var password: String = ""
    var encryptionKey: String = ""

    var normalizedScheme: String {
        let value = scheme.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value == "http" ? "http" : "https"
    }

    var normalizedHost: String {
        host.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedPort: Int? {
        let value = port.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, let parsed = Int(value), (1...65535).contains(parsed) else { return nil }
        return parsed
    }

    var normalizedPath: String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "/"
        }

        var result = trimmed
        if !result.hasPrefix("/") {
            result = "/" + result
        }

        while result.count > 1 && result.hasSuffix("/") {
            result.removeLast()
        }

        return result
    }

    var normalizedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedPassword: String {
        password
    }

    var normalizedEncryptionKey: String {
        encryptionKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var rootURL: URL? {
        guard !normalizedHost.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = normalizedScheme
        components.host = normalizedHost
        components.path = "/"
        if let normalizedPort {
            components.port = normalizedPort
        }

        return components.url
    }

    var baseURL: URL? {
        guard !normalizedHost.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = normalizedScheme
        components.host = normalizedHost
        components.path = normalizedPath
        if let normalizedPort {
            components.port = normalizedPort
        }

        return components.url
    }

    var snapshotFileName: String {
        "pixia-bills-sync.enc"
    }

    var snapshotFileURL: URL? {
        baseURL?.appendingPathComponent(snapshotFileName)
    }

    var endpointDescription: String {
        guard let baseURL else { return "(未配置)" }
        return baseURL.absoluteString
    }

    var isValid: Bool {
        baseURL != nil && !normalizedEncryptionKey.isEmpty
    }
}
