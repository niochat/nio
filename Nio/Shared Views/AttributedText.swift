//
//  AttributedText.swift
//  Nio
//
//  Created by Vincent Esche on 4/28/20.
//  Copyright © 2020 Kilian Koeltzsch. All rights reserved.
//

import SwiftUI

struct AttributedText: UIViewRepresentable {
    typealias UIViewType = UITextView

    @Binding var attributedText: NSAttributedString
    @Binding var linkTextAttributes: [NSAttributedString.Key: Any]

    @Binding var calculatedHeight: CGFloat

    @State var isEditable: Bool

    var onDone: (() -> Void)?
    var onLinkTapped: ((URL) -> Bool)?

    func makeUIView(context: UIViewRepresentableContext<AttributedText>) -> UITextView {
        let textView = UITextView()

        textView.attributedText = attributedText
        textView.linkTextAttributes = linkTextAttributes

        textView.textContainer.lineBreakMode = .byCharWrapping
        textView.textContainer.lineFragmentPadding = 0.0

        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear

        textView.isEditable = self.isEditable
        textView.isSelectable = true
        textView.isScrollEnabled = false

        textView.dataDetectorTypes = .link
        textView.delegate = context.coordinator

        if onDone != nil {
            textView.returnKeyType = .done
        }

        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        return textView
    }

    func updateUIView(_ textView: UITextView, context: UIViewRepresentableContext<AttributedText>) {
        if textView.attributedText != self.attributedText {
            textView.attributedText = self.attributedText
        }

//        if textView.window != nil, !textView.isFirstResponder, self.isEditable {
//            textView.becomeFirstResponder()
//        }

        textView.isEditable = self.isEditable

        AttributedText.recalculateHeight(textView: textView, result: $calculatedHeight)
    }

    fileprivate static func recalculateHeight(textView: UITextView, result: Binding<CGFloat>) {
//        let maxWidth = min(textView.contentSize.width, textView.bounds.size.width)
        let maxWidth = textView.frame.size.width
        let boundarySize = CGSize(
            width: maxWidth,
            height: CGFloat.greatestFiniteMagnitude
        )
        let newSize = textView.sizeThatFits(boundarySize)

        guard result.wrappedValue != newSize.height else {
            return
        }

        DispatchQueue.main.async {
            // must be called asynchronously:
            result.wrappedValue = newSize.height
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(
            attributedText: $attributedText,
            height: $calculatedHeight,
            onDone: onDone,
            onLinkTapped: onLinkTapped
        )
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var attributedText: Binding<NSAttributedString>
        var calculatedHeight: Binding<CGFloat>

        var onDone: (() -> Void)?
        var onLinkTapped: ((URL) -> Bool)?

        init(
            attributedText: Binding<NSAttributedString>,
            height: Binding<CGFloat>,
            onDone: (() -> Void)? = nil,
            onLinkTapped: ((URL) -> Bool)? = nil
        ) {
            self.attributedText = attributedText
            self.calculatedHeight = height
            self.onDone = onDone
            self.onLinkTapped = onLinkTapped
        }

        func textViewDidChange(_ textView: UITextView) {
            attributedText.wrappedValue = textView.attributedText
            AttributedText.recalculateHeight(textView: textView, result: calculatedHeight)
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            guard let onDone = self.onDone, text == "\n" else {
                return true
            }

            textView.resignFirstResponder()
            onDone()

            return false
        }

        func textView(
            _ textView: UITextView,
            shouldInteractWith url: URL,
            in characterRange: NSRange,
            interaction: UITextItemInteraction
        ) -> Bool {
            return onLinkTapped?(url) ?? false
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
            linkTextAttributes: .constant([
                .foregroundColor: UIColor.blue,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ]),
            calculatedHeight: .constant(0),
            isEditable: false
        )
            .previewLayout(.sizeThatFits)
    }
}
