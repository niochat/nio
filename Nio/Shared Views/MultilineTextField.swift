import SwiftUI
import UIKit

struct MultilineTextField: View {
    @Binding private var attributedText: NSAttributedString
    @Binding private var isEditing: Bool
    @Binding private var calculatedHeight: CGFloat

    private let placeholder: String

    private let onEditingChanged: ((Bool) -> Void)?
    private let onCommit: (() -> Void)?

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
        calculatedHeight: Binding<CGFloat>,
        isEditing: Binding<Bool>,
        returnKeyType: UIReturnKeyType? = .default,
        textAlignment: NSTextAlignment? = nil,
        linkTextAttributes: [NSAttributedString.Key: Any]? = nil,
        clearsOnInsertion: Bool = false,
        contentType: UITextContentType? = nil,
        autocorrectionType: UITextAutocorrectionType = .default,
        autocapitalizationType: UITextAutocapitalizationType = .none,
        lineLimit: Int? = nil,
        lineBreakMode: NSLineBreakMode? = .byCharWrapping,
        isSecure: Bool = false,
        isEditable: Bool = true,
        isSelectable: Bool = true,
        isScrollingEnabled: Bool = false,
        onEditingChanged: ((Bool) -> Void)? = nil,
        onCommit: (() -> Void)? = nil
    ) {
        self._attributedText = attributedText
        self.placeholder = placeholder
        self._calculatedHeight = calculatedHeight
        self._isEditing = isEditing

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

        self.onEditingChanged = onEditingChanged
        self.onCommit = onCommit
    }

    var body: some View {
        AttributedText(
            attributedText: $attributedText,
            isEditing: $isEditing,
            calculatedHeight: $calculatedHeight,
            textContainerInset: textContainerInset,
            lineFragmentPadding: lineFragmentPadding,
            returnKeyType: returnKeyType,
            textAlignment: textAlignment,
            linkTextAttributes: linkTextAttributes,
            clearsOnInsertion: clearsOnInsertion,
            contentType: contentType,
            autocorrectionType: autocorrectionType,
            autocapitalizationType: autocapitalizationType,
            lineLimit: lineLimit,
            lineBreakMode: lineBreakMode,
            isSecure: isSecure,
            isEditable: isEditable,
            isSelectable: isSelectable,
            isScrollingEnabled: isScrollingEnabled,
            onEditingChanged: onEditingChanged,
            onCommit: onCommit
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
