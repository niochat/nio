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
}
