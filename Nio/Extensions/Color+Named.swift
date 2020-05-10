import SwiftUI

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

extension UIColor {
    static func textOnAccentColor(for colorScheme: ColorScheme) -> UIColor {
        messageTextColor(for: colorScheme, isOutgoing: true)
    }

    static func messageTextColor(for colorScheme: ColorScheme,
                                 isOutgoing: Bool) -> UIColor {
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
