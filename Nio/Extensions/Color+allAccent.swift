import SwiftUI

extension Color {
    static var allAccentOptions: [Color] {
        [
            .purple,
            .blue,
            .red,
            .orange,
            .green,
            .gray,
            .yellow
        ]
    }

    init?(description: String) {
        switch description {
        case "purple": self = .purple
        case "blue": self = .blue
        case "red": self = .red
        case "orange": self = .orange
        case "green": self = .green
        case "gray": self = .gray
        case "yellow": self = .yellow
        default: self = .purple
        }
    }
}
