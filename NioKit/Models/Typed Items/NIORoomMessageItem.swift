import SwiftMatrixSDK

public struct NIORoomMessageItem: NIORoomStateItemProtocol {
    public struct Content: Equatable {
        var sender: String
        var body: String
    }

    public struct RepliedTo: Equatable {
        let id: String

        var content: Content
    }

    public struct Referenced: Equatable {
        let id: String
    }

    public struct Reactions: Equatable, ExpressibleByDictionaryLiteral {
        public typealias UserId = String
        public typealias Key = String

        var individual: [Key: [UserId]] = [:]

        var countsByKey: [Key: Int] {
            self.individual.mapValues { $0.count }
        }

        public init(_ individual: [Key: [UserId]] = [:]) {
            self.individual = individual
        }

        public init(dictionaryLiteral elements: (Key, [UserId])...) {
            self.init(Dictionary(uniqueKeysWithValues: elements))
        }
    }

    public let eventId: String
    public internal(set) var content: Content

    public internal(set) var reactions: Reactions?
    public internal(set) var repliedTo: RepliedTo?
    public internal(set) var referenced: Referenced?

    internal init(
        eventId: String,
        content: Content,
        reactions: Reactions? = nil,
        repliedTo: RepliedTo? = nil,
        referenced: Referenced? = nil
    ) {
        self.eventId = eventId
        self.content = content

        self.reactions = reactions
        self.repliedTo = repliedTo
        self.referenced = referenced
    }
}

extension NIORoomMessageItem: Equatable {}
