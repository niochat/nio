import Foundation

struct Reaction: Identifiable {
    var id: String
    let sender: String
    let timestamp: Date
    let reaction: String

//    var id: Int {
//        var hasher = Hasher()
//
//        self.timestamp.hash(into: &hasher)
//        self.sender.hash(into: &hasher)
//        self.reaction.hash(into: &hasher)
//
//        return hasher.finalize()
//    }
}

struct ReactionGroup: Identifiable {
    let reaction: String
    let count: Int
    let reactions: [Reaction]

    var id: String {
        self.reaction.id
    }

    func containsReaction(from sender: String) -> Bool {
        self.reactions.contains { $0.sender == sender }
    }
}
