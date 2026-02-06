import Foundation

struct IdentifiableMessage: Identifiable {
    let id = UUID()
    let message: String
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

