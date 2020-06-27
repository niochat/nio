import SwiftUI
import Smile

enum Emoji {
    struct Category: Identifiable, Hashable {
        var id: String
        var name: String
        var icon: String
    }

    static let categories = [
        Category(id: "people", name: "Smileys & People", icon: "😄"),
        Category(id: "nature", name: "Animals & Nature", icon: "🐰"),
        Category(id: "foods", name: "Food & Drink", icon: "🍔"),
        Category(id: "activity", name: "Activities", icon: "⚽️"),
        Category(id: "places", name: "Travel & Places", icon: "🗺"),
        Category(id: "objects", name: "Objects", icon: "💡"),
        Category(id: "symbols", name: "Symbols", icon: "🆒"),
        Category(id: "flags", name: "Flags", icon: "🏳️‍🌈"),
    ]

    static func emoji(forCategory categoryId: String) -> [String] {
        Smile.emojiCategories[categoryId] ?? []
    }

    static func emoji(forQuery query: String) -> [String] {
        Smile.emojiList
            .filter { $0.key.lowercased().contains(query.lowercased()) }
            .map { $0.value }
    }
}
