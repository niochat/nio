import SwiftUI

class MessageTextView: UITextView {
    var maxSize: CGSize = .zero
    
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
        isEditable = false
        isScrollEnabled = false
        linkTextAttributes = [
            .foregroundColor: linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]

        attributedText = attributedString
        self.maxSize = maxSize

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
