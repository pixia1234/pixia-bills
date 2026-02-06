import Foundation

struct JSONFileStore {
    private let fileURL: URL

    init(filename: String) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        fileURL = (documents ?? FileManager.default.temporaryDirectory).appendingPathComponent(filename)
    }

    func load<T: Decodable>(_ type: T.Type, default defaultValue: T) -> T {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder.appDecoder.decode(type, from: data)
        } catch {
            return defaultValue
        }
    }

    func save<T: Encodable>(_ value: T) {
        do {
            let data = try JSONEncoder.appEncoder.encode(value)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("[JSONFileStore] save failed: \(error)")
        }
    }
}

extension JSONEncoder {
    static var appEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var appDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
