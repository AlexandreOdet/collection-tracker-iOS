import Foundation

/// Miroir exact de `SyncedItem` (src/models.rs) côté serveur Rust.
struct SyncedItemDTO: Codable, Equatable {
    var id: UUID
    var title: String
    var type: String
    var status: String
    var rating: Int?
    var notes: String
    var updatedAt: Date
    var isDeleted: Bool
    /// JSON encodé en chaîne : champs propres à la catégorie, sans migration serveur.
    var attributesJSON: String

    enum CodingKeys: String, CodingKey {
        case id, title, type, status, rating, notes
        case updatedAt = "updated_at"
        case isDeleted = "is_deleted"
        case attributesJSON = "attributes_json"
    }
}

/// Contenu de `attributes_json`. Tous les champs sont tolérants à l'absence pour rester
/// compatibles avec d'autres versions de l'app.
struct ItemAttributes: Codable, Equatable {
    var reference: String?
    var condition: String?
    var purchasePrice: Double?
    var acquiredAt: Date?
}

struct PushRequest: Encodable {
    var changes: [SyncedItemDTO]
}

struct PullResponse: Decodable {
    var items: [SyncedItemDTO]
    var serverTime: Date

    enum CodingKeys: String, CodingKey {
        case items
        case serverTime = "server_time"
    }
}

/// Encodage/décodage des dates au format RFC 3339 attendu par chrono (`DateTime<Utc>`).
enum SyncCoding {
    private static let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let plain = Date.ISO8601FormatStyle()

    static func string(from date: Date) -> String {
        date.formatted(fractional)
    }

    static func date(from string: String) -> Date? {
        // chrono émet jusqu'à 9 décimales ; on tronque à la milliseconde (jamais vers le futur).
        let normalized = string.replacingOccurrences(
            of: #"(\.\d{3})\d+"#, with: "$1", options: .regularExpression
        )
        return (try? fractional.parse(normalized)) ?? (try? plain.parse(normalized))
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(string(from: date))
        }
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            guard let date = SyncCoding.date(from: raw) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "Date invalide : \(raw)")
                )
            }
            return date
        }
        return decoder
    }

    static func encodeAttributes(_ attributes: ItemAttributes) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(attributes) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    static func decodeAttributes(_ json: String) -> ItemAttributes {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(ItemAttributes.self, from: Data(json.utf8)))
            ?? ItemAttributes()
    }
}
