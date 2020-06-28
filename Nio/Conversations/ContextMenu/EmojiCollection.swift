import SwiftUI

class EmojiCollection {
    enum Category: String, CaseIterable, Decodable, Identifiable {
        case smileysAndEmotion = "Smileys & Emotion"
        case peopleAndBody = "People & Body"
        case animalsAndNature = "Animals & Nature"
        case foodAndDrink = "Food & Drink"
        case travelAndPlaces = "Travel & Places"
        case activities = "Activities"
        case objects = "Objects"
        case symbols = "Symbols"
        case flags = "Flags"

        var id: String {
            rawValue
        }

        var name: String {
            // FIXME: This should be localized.
            rawValue
        }

        var icon: String {
            switch self {
            case .smileysAndEmotion:
                return "😃"
            case .peopleAndBody:
                return "👋"
            case .animalsAndNature:
                return "🐰"
            case .foodAndDrink:
                return "🍔"
            case .travelAndPlaces:
                return "🌇"
            case .activities:
                return "⚽️"
            case .objects:
                return "💡"
            case .symbols:
                return "🔣"
            case .flags:
                return "🏳️‍🌈"
            }
        }

        var iconImage: Image {
            switch self {
            case .smileysAndEmotion:
                return Image(systemName: "face.smiling")
            case .peopleAndBody:
                return Image(systemName: "hand.raised")
            case .animalsAndNature:
                return Image(systemName: "leaf")
            case .foodAndDrink:
                return Image(systemName: "thermometer")
            case .travelAndPlaces:
                return Image(systemName: "car")
            case .activities:
                return Image(systemName: "figure.walk")
            case .objects:
                return Image(systemName: "lightbulb")
            case .symbols:
                return Image(systemName: "number.circle")
            case .flags:
                return Image(systemName: "flag")
            }
        }
    }

    struct Emoji: Decodable, Identifiable, Hashable {
        let emoji: String
        let description: String
        let category: Category
        let aliases: [String]
        let tags: [String]

        var id: String {
            emoji
        }
    }

    let emoji: [Emoji]
    let categorized: [Category: [Emoji]]

    init() {
        let emojiURL = Bundle.main.url(forResource: "emoji", withExtension: "json")!
        // swiftlint:disable force_try
        let emojiData = try! Data(contentsOf: emojiURL)
        emoji = try! JSONDecoder().decode([Emoji].self, from: emojiData)
        // swiftlint:enable force_try
        categorized = Dictionary(grouping: emoji, by: \.category)
    }

    func emoji(for category: Category) -> [Emoji] {
        categorized[category] ?? []
    }

    func emoji(matching query: String) -> [Emoji] {
        // swiftlint:disable:next identifier_name
        emoji.filter { e in
            let matchString = e.emoji + e.description + e.aliases.joined() + e.tags.joined()
            return matchString.lowercased().contains(query.lowercased())
        }
    }
}
