import SwiftUI
import NioKit

extension Color {
    static var borderedMessageBackground: Color = .init(Asset.Color.borderedMessageBackground.name)

    static func backgroundColor(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return .black
        } else {
            return .white
        }
    }
}

extension UXColor {
    /// Color of text that is shown on top of the accent color, e.g. badges.
    static func textOnAccentColor(for colorScheme: ColorScheme) -> UXColor {
        messageTextColor(for: colorScheme, isOutgoing: true)
    }

    static func messageTextColor(for colorScheme: ColorScheme,
                                 isOutgoing: Bool) -> UXColor {
        if isOutgoing {
            return .white
        }
        switch colorScheme {
        case .dark:
            return .white
        default:
            return .black
        }
    }
}
