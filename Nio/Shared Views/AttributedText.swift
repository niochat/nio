//
//  AttributedText.swift
//  Nio
//
//  Created by Vincent Esche on 4/28/20.
//  Copyright © 2020 Kilian Koeltzsch. All rights reserved.
//

import SwiftUI

// Adapted from https://stackoverflow.com/a/60441078/227536

struct AttributedText: UIViewRepresentable {
    class HeightUITextView: UITextView {
        @Binding var height: CGFloat

        init(height: Binding<CGFloat>) {
            _height = height
            super.init(frame: .zero, textContainer: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            let maxSize = CGSize(width: frame.size.width,
                                 height: CGFloat.greatestFiniteMagnitude)
            let newSize = sizeThatFits(maxSize)
            if height != newSize.height {
                height = newSize.height
            }
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: AttributedText

        init(_ view: AttributedText) {
            parent = view
        }

        func textView(_ textView: UITextView,
                      shouldInteractWith URL: URL,
                      in characterRange: NSRange,
                      interaction: UITextItemInteraction
        ) -> Bool {
            parent.linkTapped(URL)
            return false
        }
    }

    let attributedString: NSAttributedString

    @Binding var height: CGFloat

    let linkTapped: (URL) -> Void

    public func makeUIView(context: Context) -> UITextView {
        let textView = HeightUITextView(height: $height)

        textView.attributedText = attributedString
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isUserInteractionEnabled = true
        textView.delegate = context.coordinator
        textView.isScrollEnabled = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        textView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        textView.dataDetectorTypes = .link
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0

        self.updateHeightFor(textView: textView)

        return textView
    }

    public func updateUIView(_ textView: UITextView, context: Context) {
        if textView.attributedText != attributedString {
            textView.attributedText = attributedString
        }

        self.updateHeightFor(textView: textView)
    }

    private func updateHeightFor(textView: UITextView) {
        let fixedWidth = textView.frame.size.width
        let newSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))

        DispatchQueue.main.async {
            self.height = newSize.height
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

struct AttributedText_Previews: PreviewProvider {
    static var previews: some View {
        let attributedString = NSAttributedString(
            string: "Hello world!",
            attributes: [
                NSAttributedString.Key.font: UIFont.labelFontSize,
                NSAttributedString.Key.foregroundColor: UIColor.red,
            ]
        )
        return AttributedText(attributedString: attributedString, height: .constant(0)) { _ in }
            .previewLayout(.sizeThatFits)
    }
}
