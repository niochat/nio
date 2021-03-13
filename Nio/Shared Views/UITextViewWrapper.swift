import SwiftUI

struct UITextViewWrapper: UIViewRepresentable {
    class TextView: UITextView {
        private let newLineModifiers: [UIKeyboardHIDUsage] = [
            .keyboardLeftShift,
            .keyboardRightShift,
            .keyboardLeftAlt,
            .keyboardRightAlt
        ]

        private var currentModifiers: Set<UIKeyboardHIDUsage> = []
        var shouldCommit: Bool { currentModifiers.isEmpty }
        var onCommit: (() -> Void)?

        private func newLineKeyCodes(in presses: Set<UIPress>) -> [UIKeyboardHIDUsage] {
            presses.compactMap { $0.key?.keyCode }.filter { newLineModifiers.contains($0) }
        }

        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            #if !targetEnvironment(macCatalyst)     // the return key isn't surfaced here in catalyst?! (macOS 11.2.1)
                                                    // avoid the potential of handling it twice if that ever changes
            if shouldCommit && presses.contains(where: { $0.key?.keyCode == .keyboardReturnOrEnter }) {
                onCommit?()
            }
            #endif
            
            let presses = shouldCommit ? presses.filter { $0.key?.keyCode != .keyboardReturnOrEnter } : presses
            super.pressesBegan(presses, with: event)

            let keyCodes = newLineKeyCodes(in: presses)
            keyCodes.forEach { currentModifiers.insert($0) }
        }

        override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            let presses = shouldCommit ? presses.filter { $0.key?.keyCode != .keyboardReturnOrEnter } : presses
            super.pressesEnded(presses, with: event)

            let keyCodes = newLineKeyCodes(in: presses)
            keyCodes.forEach { currentModifiers.remove($0) }
        }
    }

    @Environment(\.textAttributes)
    private var envTextAttributes: TextAttributes

    @Binding private var attributedText: NSAttributedString
    @Binding private var isEditing: Bool
    @Binding private var sizeThatFits: CGSize

    private let maxSize: CGSize

    private let textAttributes: TextAttributes

    private let onLinkInteraction: (((URL, UITextItemInteraction) -> Bool))?
    private let onEditingChanged: ((Bool) -> Void)?
    private let onCommit: (() -> Void)?

    init(
        attributedText: Binding<NSAttributedString>,
        isEditing: Binding<Bool>,
        sizeThatFits: Binding<CGSize>,
        maxSize: CGSize,
        textAttributes: TextAttributes = .init(),
        onLinkInteraction: ((URL, UITextItemInteraction) -> Bool)? = nil,
        onEditingChanged: ((Bool) -> Void)? = nil,
        onCommit: (() -> Void)? = nil
    ) {
        self._attributedText = attributedText
        self._isEditing = isEditing
        self._sizeThatFits = sizeThatFits

        self.maxSize = maxSize

        self.textAttributes = textAttributes

        self.onLinkInteraction = onLinkInteraction
        self.onEditingChanged = onEditingChanged
        self.onCommit = onCommit
    }

    // swiftlint:disable:next cyclomatic_complexity
    func makeUIView(context: Context) -> TextView {
        let view = TextView()

        view.delegate = context.coordinator
        view.onCommit = onCommit

        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.textColor = UIColor.label
        view.backgroundColor = .clear

        let attrs = self.textAttributes

        if let textContainerInset = attrs.textContainerInset {
            view.textContainerInset = textContainerInset
        }
        if let lineFragmentPadding = attrs.lineFragmentPadding {
            view.textContainer.lineFragmentPadding = lineFragmentPadding
        }
        if let returnKeyType = attrs.returnKeyType {
            view.returnKeyType = returnKeyType
        }
        if let textAlignment = attrs.textAlignment {
            view.textAlignment = textAlignment
        }
        if let linkTextAttributes = attrs.linkTextAttributes {
            view.linkTextAttributes = linkTextAttributes
        }
        if let linkTextAttributes = attrs.linkTextAttributes {
            view.linkTextAttributes = linkTextAttributes
        }
        if let clearsOnInsertion = attrs.clearsOnInsertion {
            view.clearsOnInsertion = clearsOnInsertion
        }
        if let contentType = attrs.contentType {
            view.textContentType = contentType
        }
        if let autocorrectionType = attrs.autocorrectionType {
            view.autocorrectionType = autocorrectionType
        }
        if let autocapitalizationType = attrs.autocapitalizationType {
            view.autocapitalizationType = autocapitalizationType
        }
        if let isSecure = attrs.isSecure {
            view.isSecureTextEntry = isSecure
        }
        if let isEditable = attrs.isEditable {
            view.isEditable = isEditable
        }
        if let isSelectable = attrs.isSelectable {
            view.isSelectable = isSelectable
        }
        if let isScrollingEnabled = attrs.isScrollingEnabled {
            view.isScrollEnabled = isScrollingEnabled
        }
        if let lineLimit = attrs.lineLimit {
            view.textContainer.maximumNumberOfLines = lineLimit
        }
        if let lineBreakMode = attrs.lineBreakMode {
            view.textContainer.lineBreakMode = lineBreakMode
        }

        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        return view
    }

    func updateUIView(_ uiView: TextView, context: Context) {
        uiView.attributedText = attributedText
        if isEditing {
            uiView.becomeFirstResponder()
        } else {
            uiView.resignFirstResponder()
        }
        UITextViewWrapper.recalculateHeight(
            view: uiView,
            maxContentSize: self.maxSize,
            result: $sizeThatFits
        )
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(
            attributedText: $attributedText,
            isEditing: $isEditing,
            sizeThatFits: $sizeThatFits,
            maxContentSize: { self.maxSize },
            onLinkInteraction: onLinkInteraction,
            onEditingChanged: onEditingChanged,
            onCommit: onCommit
        )
    }

    fileprivate static func recalculateHeight(
        view: UIView,
        maxContentSize: CGSize,
        result: Binding<CGSize>
    ) {
        let sizeThatFits = view.sizeThatFits(maxContentSize)
        if result.wrappedValue != sizeThatFits {
            DispatchQueue.main.async {
                // Must be called asynchronously:
                result.wrappedValue = sizeThatFits
            }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var attributedText: NSAttributedString
        @Binding var isEditing: Bool
        @Binding var sizeThatFits: CGSize

        private let maxContentSize: () -> CGSize

        private var onLinkInteraction: (((URL, UITextItemInteraction) -> Bool))?
        private var onEditingChanged: ((Bool) -> Void)?
        private var onCommit: (() -> Void)?

        init(
            attributedText: Binding<NSAttributedString>,
            isEditing: Binding<Bool>,
            sizeThatFits: Binding<CGSize>,
            maxContentSize: @escaping () -> CGSize,
            onLinkInteraction: ((URL, UITextItemInteraction) -> Bool)?,
            onEditingChanged: ((Bool) -> Void)?,
            onCommit: (() -> Void)?
        ) {
            self._attributedText = attributedText
            self._isEditing = isEditing
            self._sizeThatFits = sizeThatFits

            self.maxContentSize = maxContentSize

            self.onLinkInteraction = onLinkInteraction
            self.onEditingChanged = onEditingChanged
            self.onCommit = onCommit
        }

        func textViewDidChange(_ uiView: UITextView) {
            attributedText = uiView.attributedText
            onEditingChanged?(true)
            UITextViewWrapper.recalculateHeight(
                view: uiView,
                maxContentSize: maxContentSize(),
                result: $sizeThatFits
            )
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
        }

        func textView(
            _ textView: UITextView,
            shouldInteractWith url: URL,
            in characterRange: NSRange,
            interaction: UITextItemInteraction
        ) -> Bool {
            return onLinkInteraction?(url, interaction) ?? true
        }

        #if targetEnvironment(macCatalyst)
        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            guard
                text == "\n",
                let textView = textView as? TextView,
                textView.shouldCommit
            else {
                return true
            }

            DispatchQueue.main.async {
                self.onCommit?()
            }

            return false
        }
        #endif
    }
}

struct UITextViewWrapper_Previews: PreviewProvider {
    static var previews: some View {
        let attributedString = NSAttributedString(
            string: "Hello world!",
            attributes: [
                NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body),
                NSAttributedString.Key.foregroundColor: UIColor.red,
            ]
        )
        return UITextViewWrapper(
            attributedText: .constant(attributedString),
            isEditing: .constant(false),
            sizeThatFits: .constant(.zero),
            maxSize: CGSize(width: 400.0, height: 1000.0),
            textAttributes: .init(isEditable: false)
        )
            .previewLayout(.sizeThatFits)
    }
}
