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

    var legacySnapshotFileName: String {
        "pixia-bills-sync.enc"
    }

    var legacySnapshotFileURL: URL? {
        fileURL(fileName: legacySnapshotFileName)
    }

    var snapshotManifestPrefix: String {
        "pixia-bills-sync-v"
    }

    var snapshotManifestSuffix: String {
        "-manifest.enc"
    }

    var transactionChunkSize: Int {
        10_000
    }

    var endpointStateKey: String {
        [
            normalizedScheme,
            normalizedHost,
            String(normalizedPort ?? 0),
            normalizedPath,
            normalizedUsername
        ].joined(separator: "|")
    }

    func manifestFileName(version: Int) -> String {
        String(format: "%@%08d%@", snapshotManifestPrefix, version, snapshotManifestSuffix)
    }

    func transactionChunkFileName(version: Int, chunkIndex: Int) -> String {
        String(format: "pixia-bills-sync-v%08d-part-%04d.enc", version, chunkIndex)
    }

    func parseVersion(fromManifestFileName fileName: String) -> Int? {
        guard fileName.hasPrefix(snapshotManifestPrefix),
              fileName.hasSuffix(snapshotManifestSuffix) else {
            return nil
        }

        let begin = fileName.index(fileName.startIndex, offsetBy: snapshotManifestPrefix.count)
        let end = fileName.index(fileName.endIndex, offsetBy: -snapshotManifestSuffix.count)
        guard begin < end else { return nil }

        return Int(fileName[begin..<end])
    }

    func fileURL(fileName: String) -> URL? {
        baseURL?.appendingPathComponent(fileName)
    }

    var endpointDescription: String {
        guard let baseURL else { return "(未配置)" }
        return baseURL.absoluteString
    }

    var isValid: Bool {
        baseURL != nil && !normalizedEncryptionKey.isEmpty
    }
}
