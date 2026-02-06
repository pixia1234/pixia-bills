import Foundation

struct LLMImportConfiguration {
    var apiBase: String
    var apiKey: String
    var model: String

    var endpointURL: URL? {
        let trimmed = apiBase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasSuffix("/chat/completions") {
            return URL(string: trimmed)
        }
        if trimmed.hasSuffix("/v1") {
            return URL(string: trimmed + "/chat/completions")
        }
        if trimmed.hasSuffix("/v1/") {
            return URL(string: trimmed + "chat/completions")
        }
        if trimmed.hasSuffix("/") {
            return URL(string: trimmed + "v1/chat/completions")
        }
        return URL(string: trimmed + "/v1/chat/completions")
    }

    var normalizedKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedModel: String {
        model.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct LLMImportedTransactionDraft: Identifiable, Hashable {
    let id: UUID
    var type: String
    var amount: String
    var categoryName: String
    var accountName: String
    var note: String
    var dateText: String

    init(
        id: UUID = UUID(),
        type: String,
        amount: String,
        categoryName: String,
        accountName: String,
        note: String,
        dateText: String
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.categoryName = categoryName
        self.accountName = accountName
        self.note = note
        self.dateText = dateText
    }
}
