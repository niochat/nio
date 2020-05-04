//
//  MarkdownText.swift
//  Nio
//
//  Created by Vincent Esche on 4/28/20.
//  Copyright © 2020 Kilian Koeltzsch. All rights reserved.
//

import SwiftUI

import CommonMarkAttributedString

struct MarkdownText: View {
    @Binding var markdownString: String
    @Binding var linkTextAttributes: [NSAttributedString.Key: Any]

    @State var dynamicHeight: CGFloat = 0.0

    let onLinkTapped: (URL) -> Bool

    internal var attributedText: Binding<NSAttributedString> {
        Binding<NSAttributedString>(
            get: {
                let markdownString = self.markdownString.trimmingCharacters(in: .whitespacesAndNewlines)
                let attributes: [NSAttributedString.Key: Any] = [
                    NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body),
                    NSAttributedString.Key.foregroundColor: UIColor.label,
                ]
                let attributedString = try? NSAttributedString(
                    commonmark: markdownString,
                    attributes: attributes
                )
                return attributedString ?? NSAttributedString(
                    string: markdownString,
                    attributes: attributes
                )
            },
            set: {
                self.markdownString = $0.string
            }
        )
    }

    var body: some View {
        return AttributedText(
            attributedText: self.attributedText,
            linkTextAttributes: self.$linkTextAttributes,
            calculatedHeight: self.$dynamicHeight,
            isEditable: false
        )
        .frame(minHeight: dynamicHeight, maxHeight: dynamicHeight)
    }
}

struct MarkdownText_Previews: PreviewProvider {
    static var previews: some View {
        let markdownString = #"""
        # [Universal Declaration of Human Rights][udhr]

        ## Article 1.

        All human beings are born free and equal in dignity and rights.
        They are endowed with reason and conscience
        and should act towards one another in a spirit of brotherhood.

        [udhr]: https://www.un.org/en/universal-declaration-human-rights/ "View full version"
        """#
        return MarkdownText(
            markdownString: .constant(markdownString),
            linkTextAttributes: .constant([
                .foregroundColor: UIColor.blue,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ])
        ) { url in
            print("Tapped URL:", url)
            return true
        }
            .padding(10.0)
            .previewLayout(.sizeThatFits)
    }
}
