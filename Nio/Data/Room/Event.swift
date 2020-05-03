import Foundation
import SwiftMatrixSDK

// Implementation heavily inspired by [Messagerie](https://github.com/manuroe/messagerie).

struct Event: Identifiable, Codable {
    var id: String {
        eventId
    }

    var eventId: String

    var sender: String
    var senderDisplayName: String
    var senderAvatar: URL?

    var isIncoming: Bool = true

    var content: Content

    var timestamp: Date
}

extension Event {
    enum Content {
        case text(String)
        case image(ImageContent)

        case unsupported(String)
    }

    struct ImageContent: Codable {
        let url: URL
        let size: CGSize
    }
}

extension Event.Content: Codable {
    private enum CodingKeys: String, CodingKey {
        case text
        case image
        case unsupported
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? container.decode(String.self, forKey: .text) {
            self = .text(value)
        } else if let value = try? container.decode(Event.ImageContent.self, forKey: .image) {
            self = .image(value)
        } else if let value = try? container.decode(String.self, forKey: .unsupported) {
            self = .unsupported(value)
        }
        fatalError("Failed to decode event content: \(dump(container))")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode(text, forKey: .text)
        case .image(let image):
            try container.encode(image, forKey: .image)
        case .unsupported(let unsupported):
            try container.encode(unsupported, forKey: .unsupported)
        }
    }
}
