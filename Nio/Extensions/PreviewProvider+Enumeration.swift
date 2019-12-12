import SwiftUI

extension PreviewProvider {
    static func enumeratingColorSchemes<Content>(
        _ colorSchemes: [ColorScheme] = ColorScheme.allCases,
        _ content: @escaping () -> Content
    ) -> some View where Content: View {
        ForEach(colorSchemes, id: \.self) { colorScheme in
            Group {
                content()
            }
                .environment(\.colorScheme, colorScheme)
                .background(Color.backgroundColor(for: colorScheme))
        }
    }

    static func enumeratingSizeCategories<Content>(
        _ sizeCategories: [ContentSizeCategory] = ContentSizeCategory.allCases,
        _ content: @escaping () -> Content
    ) -> some View where Content: View {
        Group {
            List {
                ForEach(sizeCategories, id: \.self) { sizeCategory in
                    content().environment(\.sizeCategory, sizeCategory)
                }
            }
        }
    }
}
