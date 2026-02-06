import Foundation

enum LLMImportServiceError: LocalizedError {
    case invalidConfiguration
    case invalidResponse
    case requestFailed(String)
    case emptyResult
    case parseFailed

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "请先在设置中配置 API Base、API Key、模型"
        case .invalidResponse:
            return "LLM 返回格式不正确"
        case let .requestFailed(message):
            return message
        case .emptyResult:
            return "未识别到可导入的账单条目"
        case .parseFailed:
            return "识别结果解析失败，请重试或更换图片"
        }
    }
}

struct LLMImportService {
    func parseTransactionsFromImage(
        imageData: Data,
        configuration: LLMImportConfiguration,
        extraInstruction: String
    ) async throws -> [LLMImportedTransactionDraft] {
        guard let endpoint = configuration.endpointURL,
              !configuration.normalizedKey.isEmpty,
              !configuration.normalizedModel.isEmpty else {
            throw LLMImportServiceError.invalidConfiguration
        }

        let base64Image = imageData.base64EncodedString()
        let prompt = extraInstruction.trimmingCharacters(in: .whitespacesAndNewlines)

        let systemPrompt = """
        你是中文记账 OCR 助手。请识别图片中的账单信息，并只返回 JSON。
        JSON 格式固定为：
        {"transactions":[{"type":"expense","amount":"12.34","category":"餐饮","account":"现金","note":"午餐","date":"2026-02-06T12:00:00+08:00"}]}

        规则：
        1) type 只能是 expense 或 income。
        2) amount 必须是正数字符串。
        3) category/account/note/date 识别不到可以空字符串。
        4) 严禁输出 markdown 代码块与解释文本。
        """

        let userPrompt: String
        if prompt.isEmpty {
            userPrompt = "请识别这张票据图片并输出可导入的交易条目。"
        } else {
            userPrompt = "请识别这张票据图片并输出可导入交易条目。额外要求：\(prompt)"
        }

        let body: [String: Any] = [
            "model": configuration.normalizedModel,
            "temperature": 0,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": userPrompt],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.normalizedKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMImportServiceError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let message = decodeErrorMessage(from: data) ?? "请求失败：HTTP \(httpResponse.statusCode)"
            throw LLMImportServiceError.requestFailed(message)
        }

        guard let content = extractMessageContent(from: data) else {
            throw LLMImportServiceError.invalidResponse
        }

        let jsonText = extractJSONObject(from: content) ?? content
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw LLMImportServiceError.parseFailed
        }

        let payload: LLMResponsePayload
        do {
            payload = try JSONDecoder().decode(LLMResponsePayload.self, from: jsonData)
        } catch {
            throw LLMImportServiceError.parseFailed
        }

        let drafts = payload.transactions.compactMap { item -> LLMImportedTransactionDraft? in
            let type = item.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard type == "expense" || type == "income" else { return nil }

            let amount = item.amount.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !amount.isEmpty else { return nil }

            return LLMImportedTransactionDraft(
                type: type,
                amount: amount,
                categoryName: item.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                accountName: item.account?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                note: item.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                dateText: item.date?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            )
        }

        guard !drafts.isEmpty else {
            throw LLMImportServiceError.emptyResult
        }

        return drafts
    }

    private func decodeErrorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)
        }

        if let error = object["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }

        return object["message"] as? String
    }

    private func extractMessageContent(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = object["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            return nil
        }

        if let content = message["content"] as? String {
            return content
        }

        if let contentParts = message["content"] as? [[String: Any]] {
            return contentParts
                .compactMap { $0["text"] as? String }
                .joined(separator: "\n")
        }

        return nil
    }

    private func extractJSONObject(from text: String) -> String? {
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}") else {
            return nil
        }

        return String(cleaned[start ... end])
    }
}

private struct LLMResponsePayload: Decodable {
    struct Item: Decodable {
        let type: String
        let amount: String
        let category: String?
        let account: String?
        let note: String?
        let date: String?
    }

    let transactions: [Item]
}
