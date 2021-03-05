import SwiftUI
import NioKit

#if os(macOS)
class MessageTextView: NSTextView {
    convenience init(attributedString: NSAttributedString, linkColor: UXColor,
                     maxSize: CGSize)
    {
        self.init()
        backgroundColor = .clear
        textContainerInset = .zero
        isEditable = false
        linkTextAttributes = [
            .foregroundColor: linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]

        self.insertText(attributedString,
                        replacementRange: NSRange(location: 0, length: 0))
        self.maxSize = maxSize

        // don't resist text wrapping across multiple lines
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
}

struct MessageTextViewWrapper: NSViewRepresentable {
    let attributedString: NSAttributedString
    let linkColor: NSColor
    let maxSize: CGSize

    func makeNSView(context: Context) -> MessageTextView {
        MessageTextView(attributedString: attributedString, linkColor: linkColor, maxSize: maxSize)
    }

    func updateNSView(_ uiView: MessageTextView, context: Context) {
        // nothing to update
    }

    func makeCoordinator() {
        // nothing to coordinate
    }
}
#else // iOS
/// An automatically sized label, which allows links to be tapped.
class MessageTextView: UITextView {
    var maxSize: CGSize = .zero

    // Allows SwiftUI to automatically size the label appropriately
    override var intrinsicContentSize: CGSize {
        sizeThatFits(CGSize(width: maxSize.width, height: .infinity))
    }

    convenience init(attributedString: NSAttributedString, linkColor: UIColor, maxSize: CGSize) {
        self.init()

        font = UIFont.preferredFont(forTextStyle: .body)
        textColor = UIColor.label
        backgroundColor = .clear
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        dataDetectorTypes = .all
        isEditable = false
        isScrollEnabled = false
        linkTextAttributes = [
            .foregroundColor: linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]

        attributedText = attributedString
        self.maxSize = maxSize

        // don't resist text wrapping across multiple lines
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
}

struct MessageTextViewWrapper: UIViewRepresentable {
    let attributedString: NSAttributedString
    let linkColor: UIColor
    let maxSize: CGSize

    func makeUIView(context: Context) -> MessageTextView {
        MessageTextView(attributedString: attributedString, linkColor: linkColor, maxSize: maxSize)
    }

    func updateUIView(_ uiView: MessageTextView, context: Context) {
        // nothing to update
    }

    func makeCoordinator() {
        // nothing to coordinate
    }
}
#endif // iOS
