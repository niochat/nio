import SwiftUI

extension Color: RawRepresentable {
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

    public init?(rawValue: String) {
        switch rawValue {
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

    public var rawValue: String { description }
}
