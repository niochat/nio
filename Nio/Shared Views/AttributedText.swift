import SwiftUI
import NioKit

struct ContentSizeThatFitsKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct TextAttributesKey: EnvironmentKey {
    static var defaultValue: TextAttributes = .init()
}

extension EnvironmentValues {
    var textAttributes: TextAttributes {
        get { self[TextAttributesKey.self] }
        set { self[TextAttributesKey.self] = newValue }
    }
}

struct TextAttributesModifier: ViewModifier {
    let textAttributes: TextAttributes

    func body(content: Content) -> some View {
        content.environment(\.textAttributes, self.textAttributes)
    }
}

extension View {
    func textAttributes(_ textAttributes: TextAttributes) -> some View {
        self.modifier(TextAttributesModifier(textAttributes: textAttributes))
    }
}

struct TextAttributes {
    var textContainerInset: UXEdgeInsets? = nil
    var lineFragmentPadding: CGFloat? = nil
  #if os(macOS)
  #else
    var returnKeyType: UIReturnKeyType? = nil
  #endif
    var textAlignment: NSTextAlignment? = nil
    var linkTextAttributes: [NSAttributedString.Key: Any]? = nil
    var clearsOnInsertion: Bool? = nil
  #if os(macOS)
  #else
    var contentType: UITextContentType? = nil
    var autocorrectionType: UITextAutocorrectionType? = nil
    var autocapitalizationType: UITextAutocapitalizationType? = nil
  #endif
    var lineLimit: Int? = nil
    var lineBreakMode: NSLineBreakMode? = nil
    var isSecure: Bool? = nil
    var isEditable: Bool? = nil
    var isSelectable: Bool? = nil
    var isScrollingEnabled: Bool? = nil

    fileprivate static var `default`: Self {
      #if os(macOS)
        return Self(
            textContainerInset: .init(top: 8.0, left: 0.0, bottom: 8.0, right: 0.0),
            lineFragmentPadding: 8.0,
            textAlignment: nil,
            linkTextAttributes: nil,
            clearsOnInsertion: false,
            lineLimit: nil,
            lineBreakMode: .byWordWrapping,
            isSecure: false,
            isEditable: true,
            isSelectable: true,
            isScrollingEnabled: true
        )
      #else
        return .init(
            textContainerInset: .init(top: 8.0, left: 0.0, bottom: 8.0, right: 0.0),
            lineFragmentPadding: 8.0,
            returnKeyType: .default,
            textAlignment: nil,
            linkTextAttributes: nil,
            clearsOnInsertion: false,
            contentType: nil,
            autocorrectionType: .default,
            autocapitalizationType: .some(.none),
            lineLimit: nil,
            lineBreakMode: .byWordWrapping,
            isSecure: false,
            isEditable: true,
            isSelectable: true,
            isScrollingEnabled: true
        )
      #endif
    }

  #if os(macOS)
    func overriding(_ fallback: Self) -> Self {
        let textContainerInset: UXEdgeInsets? = self.textContainerInset ?? fallback.textContainerInset
        let lineFragmentPadding: CGFloat? = self.lineFragmentPadding ?? fallback.lineFragmentPadding
        let textAlignment: NSTextAlignment? = self.textAlignment ?? fallback.textAlignment
        let linkTextAttributes: [NSAttributedString.Key: Any]? = self.linkTextAttributes ?? fallback.linkTextAttributes
        let clearsOnInsertion: Bool? = self.clearsOnInsertion ?? fallback.clearsOnInsertion
        let lineLimit: Int? = self.lineLimit ?? fallback.lineLimit
        let lineBreakMode: NSLineBreakMode? = self.lineBreakMode ?? fallback.lineBreakMode
        let isSecure: Bool? = self.isSecure ?? fallback.isSecure
        let isEditable: Bool? = self.isEditable ?? fallback.isEditable
        let isSelectable: Bool? = self.isSelectable ?? fallback.isSelectable
        let isScrollingEnabled: Bool? = self.isScrollingEnabled ?? fallback.isScrollingEnabled

        return .init(
            textContainerInset: textContainerInset,
            lineFragmentPadding: lineFragmentPadding,
            textAlignment: textAlignment,
            linkTextAttributes: linkTextAttributes,
            clearsOnInsertion: clearsOnInsertion,
            lineLimit: lineLimit,
            lineBreakMode: lineBreakMode,
            isSecure: isSecure,
            isEditable: isEditable,
            isSelectable: isSelectable,
            isScrollingEnabled: isScrollingEnabled
        )
    }
  #else // iOS
    func overriding(_ fallback: Self) -> Self {
        let textContainerInset: UXEdgeInsets? = self.textContainerInset ?? fallback.textContainerInset
        let lineFragmentPadding: CGFloat? = self.lineFragmentPadding ?? fallback.lineFragmentPadding
        let returnKeyType: UIReturnKeyType? = self.returnKeyType ?? fallback.returnKeyType
        let textAlignment: NSTextAlignment? = self.textAlignment ?? fallback.textAlignment
        let linkTextAttributes: [NSAttributedString.Key: Any]? = self.linkTextAttributes ?? fallback.linkTextAttributes
        let clearsOnInsertion: Bool? = self.clearsOnInsertion ?? fallback.clearsOnInsertion
        let contentType: UITextContentType? = self.contentType ?? fallback.contentType
        let autocorrectionType: UITextAutocorrectionType? = self.autocorrectionType ?? fallback.autocorrectionType
        let autocapitalizationType: UITextAutocapitalizationType? = self.autocapitalizationType ?? fallback.autocapitalizationType
        let lineLimit: Int? = self.lineLimit ?? fallback.lineLimit
        let lineBreakMode: NSLineBreakMode? = self.lineBreakMode ?? fallback.lineBreakMode
        let isSecure: Bool? = self.isSecure ?? fallback.isSecure
        let isEditable: Bool? = self.isEditable ?? fallback.isEditable
        let isSelectable: Bool? = self.isSelectable ?? fallback.isSelectable
        let isScrollingEnabled: Bool? = self.isScrollingEnabled ?? fallback.isScrollingEnabled

        return .init(
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
            isScrollingEnabled: isScrollingEnabled
        )
    }
  #endif // iOS
}

#if os(macOS)
// TODO: port to macOS. Note: This is really an `AttributedTextField`
@available(macOS, unavailable)
struct AttributedText: View {
  var body: some View { Text("`AttributedText` unavailable on macOS") }
}
#else
@available(macOS, unavailable)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)
struct AttributedText: View {
    @Environment(\.textAttributes)
    var envTextAttributes: TextAttributes

    @Binding var attributedText: NSAttributedString
    @Binding var isEditing: Bool

    @State private var sizeThatFits: CGSize = .zero

    private let textAttributes: TextAttributes

    private let onLinkInteraction: (((URL, UITextItemInteraction) -> Bool))?
    private let onEditingChanged: ((Bool) -> Void)?
    private let onCommit: (() -> Void)?

    var body: some View {
        let textAttributes = self.textAttributes
            .overriding(self.envTextAttributes)
            .overriding(TextAttributes.default)

        return GeometryReader { geometry in
            return UITextViewWrapper(
                attributedText: self.$attributedText,
                isEditing: self.$isEditing,
                sizeThatFits: self.$sizeThatFits,
                maxSize: geometry.size,
                textAttributes: textAttributes,
                onLinkInteraction: self.onLinkInteraction,
                onEditingChanged: self.onEditingChanged,
                onCommit: self.onCommit
            )
            .preference(
                key: ContentSizeThatFitsKey.self,
                value: self.sizeThatFits
            )
        }
    }

    init(
        attributedText: Binding<NSAttributedString>,
        isEditing: Binding<Bool>,
        textAttributes: TextAttributes = .init(),
        onLinkInteraction: ((URL, UITextItemInteraction) -> Bool)? = nil,
        onEditingChanged: ((Bool) -> Void)? = nil,
        onCommit: (() -> Void)? = nil
    ) {
        self._attributedText = attributedText
        self._isEditing = isEditing

        self.textAttributes = textAttributes

        self.onLinkInteraction = onLinkInteraction
        self.onEditingChanged = onEditingChanged
        self.onCommit = onCommit
    }
}

struct AttributedText_Previews: PreviewProvider {
    static var previews: some View {
        let attributedString = NSAttributedString(
            string: "Hello world!",
            attributes: [
                NSAttributedString.Key.font: UXFont.preferredFont(forTextStyle: .body),
                NSAttributedString.Key.foregroundColor: UXColor.red,
            ]
        )
        return AttributedText(
            attributedText: .constant(attributedString),
            isEditing: .constant(false),
            textAttributes: .init(isEditable: false)
        )
            .previewLayout(.sizeThatFits)
    }
}
#endif // iOS
