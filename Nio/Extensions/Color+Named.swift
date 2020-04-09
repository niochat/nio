import SwiftUI

extension Color {
    private enum CustomNames {
        static let borderedMessageBackground: String = "borderedMessageBackground"
    }

    static var borderedMessageBackground: Color = .init(CustomNames.borderedMessageBackground)

    static func backgroundColor(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return .black
        } else {
            return .white
        }
    }

    static func lightText(for colorScheme: ColorScheme,
                          with colorSchemeContrast: ColorSchemeContrast) -> Color {
        if colorSchemeContrast == .standard {
            return .white
        }
        switch colorScheme {
        case .light:
            return .white
        case .dark:
            return .black
        @unknown default:
            return .white
        }
    }

    static func primaryText(for colorScheme: ColorScheme,
                            with colorSchemeContrast: ColorSchemeContrast) -> Color {
        if colorSchemeContrast == .standard {
            return .primary
        }
        return .black
    }
}
