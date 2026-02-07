import Foundation

struct WebDAVClient {
    enum WebDAVError: LocalizedError {
        case invalidURL
        case unauthorized
        case forbidden
        case notFound
        case unexpectedStatus(code: Int, message: String?)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "WebDAV URL 无效"
            case .unauthorized:
                return "WebDAV 认证失败（用户名/密码错误或无权限）"
            case .forbidden:
                return "WebDAV 被拒绝访问（403）"
            case .notFound:
                return "WebDAV 路径不存在（404）"
            case .unexpectedStatus(let code, let message):
                if let message, !message.isEmpty {
                    return "WebDAV 请求失败（HTTP \(code)）：\(message)"
                }
                return "WebDAV 请求失败（HTTP \(code)）"
            case .invalidResponse:
                return "WebDAV 响应无效"
            }
        }
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func ping(directoryURL: URL, configuration: WebDAVSyncConfiguration) async throws {
        var request = makeRequest(url: directoryURL, method: "OPTIONS", configuration: configuration)
        request.setValue("0", forHTTPHeaderField: "Content-Length")

        let (_, response) = try await perform(request)
        try validate(response: response, allow: [200, 204, 207])
    }

    func download(url: URL, configuration: WebDAVSyncConfiguration) async throws -> Data? {
        let request = makeRequest(url: url, method: "GET", configuration: configuration)
        let (data, response) = try await perform(request)

        switch response.statusCode {
        case 200:
            return data
        case 404:
            return nil
        default:
            try validate(response: response, data: data)
            return nil
        }
    }

    func upload(data: Data, url: URL, configuration: WebDAVSyncConfiguration) async throws {
        var request = makeRequest(url: url, method: "PUT", configuration: configuration)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (_, response) = try await perform(request)
        if (200...299).contains(response.statusCode) {
            return
        }

        if response.statusCode == 404 || response.statusCode == 409 {
            if let baseURL = configuration.baseURL {
                try await ensureDirectoryExists(directoryURL: baseURL, configuration: configuration)

                var retry = makeRequest(url: url, method: "PUT", configuration: configuration)
                retry.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
                retry.httpBody = data

                let (_, retryResponse) = try await perform(retry)
                try validate(response: retryResponse)
                return
            }
        }

        try validate(response: response)
    }

    func ensureDirectoryExists(directoryURL: URL, configuration: WebDAVSyncConfiguration) async throws {
        let url = directoryURL.webdavDirectoryURL

        let status = try await mkcol(url: url, configuration: configuration)
        switch status {
        case 200, 201, 204, 405:
            return
        case 409:
            let parent = url.deletingLastPathComponent()
            if parent.path == "/" {
                throw WebDAVError.unexpectedStatus(code: status, message: "无法创建远端目录")
            }
            try await ensureDirectoryExists(directoryURL: parent, configuration: configuration)
            _ = try await mkcol(url: url, configuration: configuration)
            return
        case 401:
            throw WebDAVError.unauthorized
        case 403:
            throw WebDAVError.forbidden
        case 404:
            throw WebDAVError.notFound
        default:
            throw WebDAVError.unexpectedStatus(code: status, message: nil)
        }
    }

    private func mkcol(url: URL, configuration: WebDAVSyncConfiguration) async throws -> Int {
        let request = makeRequest(url: url, method: "MKCOL", configuration: configuration)
        let (data, response) = try await perform(request)

        if response.statusCode == 405 {
            return 405
        }

        if (200...299).contains(response.statusCode) {
            return response.statusCode
        }

        if response.statusCode == 409 {
            return 409
        }

        if [401, 403, 404].contains(response.statusCode) {
            return response.statusCode
        }

        try validate(response: response, data: data)
        return response.statusCode
    }

    private func makeRequest(url: URL, method: String, configuration: WebDAVSyncConfiguration) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30

        if !configuration.normalizedUsername.isEmpty {
            let credential = "\(configuration.normalizedUsername):\(configuration.normalizedPassword)"
            let token = Data(credential.utf8).base64EncodedString()
            request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        }

        request.setValue("pixia-bills", forHTTPHeaderField: "User-Agent")
        return request
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw WebDAVError.invalidResponse
        }
        return (data, http)
    }

    private func validate(response: HTTPURLResponse, data: Data? = nil, allow: Set<Int> = []) throws {
        if !allow.isEmpty, allow.contains(response.statusCode) {
            return
        }

        if (200...299).contains(response.statusCode) {
            return
        }

        switch response.statusCode {
        case 401:
            throw WebDAVError.unauthorized
        case 403:
            throw WebDAVError.forbidden
        case 404:
            throw WebDAVError.notFound
        default:
            var message: String?
            if let data, let text = String(data: data, encoding: .utf8) {
                message = text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            throw WebDAVError.unexpectedStatus(code: response.statusCode, message: message)
        }
    }
}

private extension URL {
    var webdavDirectoryURL: URL {
        if absoluteString.hasSuffix("/") {
            return self
        }
        return appendingPathComponent("")
    }
}
