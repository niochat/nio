import SwiftUI
import UIKit

struct MultilineTextField: View {
    @Binding private var attributedText: NSAttributedString
    @Binding private var isEditing: Bool

    @State private var contentSizeThatFits: CGSize = .zero

    private let placeholder: String
    private let textAttributes: TextAttributes

    private let onEditingChanged: ((Bool) -> Void)?
    private let onCommit: (() -> Void)?

    private var placeholderInset: EdgeInsets {
        .init(top: 8.0, leading: 8.0, bottom: 8.0, trailing: 8.0)
    }

    private var textContainerInset: UIEdgeInsets {
        .init(top: 8.0, left: 0.0, bottom: 8.0, right: 0.0)
    }

    private var lineFragmentPadding: CGFloat {
        8.0
    }

    init (
        attributedText: Binding<NSAttributedString>,
        placeholder: String = "",
        isEditing: Binding<Bool>,
        textAttributes: TextAttributes = .init(),
        onEditingChanged: ((Bool) -> Void)? = nil,
        onCommit: (() -> Void)? = nil
    ) {
        self._attributedText = attributedText
        self.placeholder = placeholder

        self._isEditing = isEditing

        self._contentSizeThatFits = State(initialValue: .zero)

        self.textAttributes = textAttributes

        self.onEditingChanged = onEditingChanged
        self.onCommit = onCommit
    }

    var body: some View {
        AttributedText(
            attributedText: $attributedText,
            isEditing: $isEditing,
            textAttributes: textAttributes,
            onEditingChanged: onEditingChanged,
            onCommit: onCommit
        )
            .onPreferenceChange(ContentSizeThatFitsKey.self) {
                self.contentSizeThatFits = $0
            }
            .frame(
                idealHeight: self.contentSizeThatFits.height
            )
            .background(placeholderView, alignment: .topLeading)
    }

    var placeholderView: some View {
        return Group {
            if attributedText.isEmpty {
                Text(placeholder).foregroundColor(.gray)
                    .padding(placeholderInset)
            }
        }
    }
}
