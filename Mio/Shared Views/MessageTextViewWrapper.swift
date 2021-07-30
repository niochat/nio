//
//  MessageTextViewWrapper.swift
//  Mio
//
//  Created by Finn Behrens on 13.06.21.
//  Copyright © 2021 Kilian Koeltzsch. All rights reserved.
//

import SwiftUI
import NioKit

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
