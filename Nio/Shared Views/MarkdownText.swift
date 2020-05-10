import SwiftUI

import CommonMarkAttributedString

struct MarkdownText: View {
    @Binding var markdown: String
    var textColor: UIColor

    @State private var calculatedHeight: CGFloat = 0.0

    let linkTextAttributes: [NSAttributedString.Key: Any]?

    let onLinkInteraction: (((URL, UITextItemInteraction) -> Bool))?

    public init(
        markdown: Binding<String>,
        textColor: UIColor,
        linkTextAttributes: [NSAttributedString.Key: Any]? = nil,
        onLinkInteraction: (((URL, UITextItemInteraction) -> Bool))? = nil
    ) {
        self._markdown = markdown
        self.textColor = textColor.resolvedColor(with: .current)
        self.linkTextAttributes = linkTextAttributes
        self.onLinkInteraction = onLinkInteraction
    }

    internal var attributes: [NSAttributedString.Key: Any] {
        [
            NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body),
            NSAttributedString.Key.foregroundColor: self.textColor,
        ]
    }

    internal var attributedText: Binding<NSAttributedString> {
        Binding<NSAttributedString>(
            get: {
                let markdownString = self.markdown.trimmingCharacters(in: .whitespacesAndNewlines)
                let attributes = self.attributes
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
                self.markdown = $0.string
            }
        )
    }

    private var textContainerInset: UIEdgeInsets {
        .init(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
    }

    private var lineFragmentPadding: CGFloat {
        0.0
    }

    var body: some View {
        AttributedText(
            attributedText: self.attributedText,
            isEditing: .constant(false),
            calculatedHeight: $calculatedHeight,
            textContainerInset: self.textContainerInset,
            lineFragmentPadding: self.lineFragmentPadding,
            linkTextAttributes: self.linkTextAttributes,
            isEditable: false,
            isScrollingEnabled: false,
            onLinkInteraction: self.onLinkInteraction
        )
        .frame(minHeight: calculatedHeight, maxHeight: calculatedHeight)
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
            markdown: .constant(markdownString),
            textColor: .messageTextColor(for: .light, isOutgoing: false),
            linkTextAttributes: [
                .foregroundColor: UIColor.blue,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ]
        ) { url, _ in
            print("Tapped URL:", url)
            return true
        }
            .padding(10.0)
            .previewLayout(.sizeThatFits)
    }
}
