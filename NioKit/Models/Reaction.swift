import Foundation

public struct Reaction: Identifiable {
    public var id: String
    public let sender: String
    public let timestamp: Date
    public let reaction: String

    public init(
        id: String,
        sender: String,
        timestamp: Date,
        reaction: String
    ) {
        self.id = id
        self.sender = sender
        self.timestamp = timestamp
        self.reaction = reaction
    }
}

public struct ReactionGroup: Identifiable {
    public let reaction: String
    public let count: Int
    public let reactions: [Reaction]

    public var id: String {
        self.reaction
    }
    
    public init(reaction: String, count: Int, reactions: [Reaction]) {
        self.reaction = reaction
        self.count = count
        self.reactions = reactions
    }

    public func containsReaction(from sender: String) -> Bool {
        self.reactions.contains { $0.sender == sender }
    }
}
