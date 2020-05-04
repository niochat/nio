import SwiftUI

struct AttributedText: UIViewRepresentable {
    typealias UIViewType = UITextView

    @Binding var attributedText: NSAttributedString
    @Binding var isEditing: Bool
    @Binding var calculatedHeight: CGFloat

    let onLinkInteraction: (((URL, UITextItemInteraction) -> Bool))?
    let onEditingChanged: ((Bool) -> Void)?
    let onCommit: (() -> Void)?

    private let textContainerInset: UIEdgeInsets
    private let lineFragmentPadding: CGFloat
    private let returnKeyType: UIReturnKeyType?
    private let textAlignment: NSTextAlignment?
    private let linkTextAttributes: [NSAttributedString.Key: Any]?
    private let clearsOnInsertion: Bool
    private let contentType: UITextContentType?
    private let autocorrectionType: UITextAutocorrectionType
    private let autocapitalizationType: UITextAutocapitalizationType
    private let lineLimit: Int?
    private let lineBreakMode: NSLineBreakMode?
    private let isSecure: Bool
    private let isEditable: Bool
    private let isSelectable: Bool
    private let isScrollingEnabled: Bool

    init(
        attributedText: Binding<NSAttributedString>,
        isEditing: Binding<Bool>,
        calculatedHeight: Binding<CGFloat>,
        textContainerInset: UIEdgeInsets = .init(top: 8.0, left: 0.0, bottom: 8.0, right: 0.0),
        lineFragmentPadding: CGFloat = 8.0,
        returnKeyType: UIReturnKeyType? = .default,
        textAlignment: NSTextAlignment? = nil,
        linkTextAttributes: [NSAttributedString.Key: Any]? = nil,
        clearsOnInsertion: Bool = false,
        contentType: UITextContentType? = nil,
        autocorrectionType: UITextAutocorrectionType = .default,
        autocapitalizationType: UITextAutocapitalizationType = .none,
        lineLimit: Int? = nil,
        lineBreakMode: NSLineBreakMode? = .byWordWrapping,
        isSecure: Bool = false,
        isEditable: Bool = true,
        isSelectable: Bool = true,
        isScrollingEnabled: Bool = true,
        onLinkInteraction: ((URL, UITextItemInteraction) -> Bool)? = nil,
        onEditingChanged: ((Bool) -> Void)? = nil,
        onCommit: (() -> Void)? = nil
    ) {
        self._attributedText = attributedText
        self._isEditing = isEditing
        self._calculatedHeight = calculatedHeight

        self.textContainerInset = textContainerInset
        self.lineFragmentPadding = lineFragmentPadding
        self.returnKeyType = returnKeyType
        self.textAlignment = textAlignment
        self.linkTextAttributes = linkTextAttributes
        self.clearsOnInsertion = clearsOnInsertion
        self.contentType = contentType
        self.autocorrectionType = autocorrectionType
        self.autocapitalizationType = autocapitalizationType
        self.lineLimit = lineLimit
        self.lineBreakMode = lineBreakMode
        self.isSecure = isSecure
        self.isEditable = isEditable
        self.isSelectable = isSelectable
        self.isScrollingEnabled = isScrollingEnabled

        self.onLinkInteraction = onLinkInteraction
        self.onEditingChanged = onEditingChanged
        self.onCommit = onCommit
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()

        view.delegate = context.coordinator

        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.textColor = UIColor.label
        view.backgroundColor = .clear

        view.textContainerInset = textContainerInset
        view.textContainer.lineFragmentPadding = lineFragmentPadding
        if let returnKeyType = returnKeyType {
            view.returnKeyType = returnKeyType
        }
        if let textAlignment = textAlignment {
            view.textAlignment = textAlignment
        }
        if let linkTextAttributes = linkTextAttributes {
            view.linkTextAttributes = linkTextAttributes
        }
        view.linkTextAttributes = linkTextAttributes
        view.clearsOnInsertion = clearsOnInsertion
        view.textContentType = contentType
        view.autocorrectionType = autocorrectionType
        view.autocapitalizationType = autocapitalizationType
        view.isSecureTextEntry = isSecure
        view.isEditable = isEditable
        view.isSelectable = isSelectable
        view.isScrollEnabled = isScrollingEnabled
        if let lineLimit = lineLimit {
            view.textContainer.maximumNumberOfLines = lineLimit
        }
        if let lineBreakMode = lineBreakMode {
            view.textContainer.lineBreakMode = lineBreakMode
        }

        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = attributedText
        if isEditing {
            uiView.becomeFirstResponder()
        } else {
            uiView.resignFirstResponder()
        }
        AttributedText.recalculateHeight(view: uiView, result: $calculatedHeight)
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(
            attributedText: $attributedText,
            isEditing: $isEditing,
            calculatedHeight: $calculatedHeight,
            onLinkInteraction: onLinkInteraction,
            onEditingChanged: onEditingChanged,
            onCommit: onCommit
        )
    }

    fileprivate static func recalculateHeight(view: UIView, result: Binding<CGFloat>) {
        let maxSize = CGSize(
            width: view.frame.size.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        let newSize = view.sizeThatFits(maxSize)
        if result.wrappedValue != newSize.height {
            DispatchQueue.main.async {
                // Must be called asynchronously:
                result.wrappedValue = newSize.height
            }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var attributedText: NSAttributedString
        @Binding var isEditing: Bool
        @Binding var calculatedHeight: CGFloat

        var onLinkInteraction: (((URL, UITextItemInteraction) -> Bool))?
        var onEditingChanged: ((Bool) -> Void)?
        var onCommit: (() -> Void)?

        init(
            attributedText: Binding<NSAttributedString>,
            isEditing: Binding<Bool>,
            calculatedHeight: Binding<CGFloat>,
            onLinkInteraction: ((URL, UITextItemInteraction) -> Bool)?,
            onEditingChanged: ((Bool) -> Void)?,
            onCommit: (() -> Void)?
        ) {
            self._attributedText = attributedText
            self._isEditing = isEditing
            self._calculatedHeight = calculatedHeight
            self.onLinkInteraction = onLinkInteraction
            self.onEditingChanged = onEditingChanged
            self.onCommit = onCommit
        }

        func textViewDidChange(_ uiView: UITextView) {
            attributedText = uiView.attributedText
            onEditingChanged?(true)
            AttributedText.recalculateHeight(view: uiView, result: $calculatedHeight)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            DispatchQueue.main.async {
                guard !self.isEditing else {
                    return
                }
                self.isEditing = true
            }

            onEditingChanged?(false)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            DispatchQueue.main.async {
                guard self.isEditing else {
                    return
                }
                self.isEditing = false
            }

            onCommit?()
        }

        func textView(
            _ textView: UITextView,
            shouldInteractWith url: URL,
            in characterRange: NSRange,
            interaction: UITextItemInteraction
        ) -> Bool {
            return onLinkInteraction?(url, interaction) ?? true
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            guard let onCommit = self.onCommit, text == "\n" else {
                return true
            }

            textView.resignFirstResponder()
            onCommit()

            return false
        }
    }
}

struct AttributedText_Previews: PreviewProvider {
    static var previews: some View {
        let attributedString = NSAttributedString(
            string: "Hello world!",
            attributes: [
                NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body),
                NSAttributedString.Key.foregroundColor: UIColor.red,
            ]
        )
        return AttributedText(
            attributedText: .constant(attributedString),
            isEditing: .constant(false),
            calculatedHeight: .constant(0),
            isEditable: false
        )
            .previewLayout(.sizeThatFits)
    }
}
