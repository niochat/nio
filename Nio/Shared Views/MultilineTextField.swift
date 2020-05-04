import SwiftUI
import UIKit

struct MultilineTextField: View {
    private var placeholder: String
    private var onCommit: (() -> Void)?

    @Binding private var attributedText: NSAttributedString {
        didSet {
            self.showingPlaceholder = self.attributedText.isEmpty
        }
    }

    @State private var dynamicHeight: CGFloat = 0.0
    @State private var showingPlaceholder = false

    init (_ placeholder: String = "", attributedText: Binding<NSAttributedString>, onCommit: (() -> Void)? = nil) {
        self.placeholder = placeholder
        self.onCommit = onCommit
        self._attributedText = attributedText
        self._showingPlaceholder = State<Bool>(initialValue: self.attributedText.isEmpty)
    }

    var body: some View {
        AttributedText(
            attributedText: self.$attributedText,
            linkTextAttributes: .constant([:]),
            calculatedHeight: $dynamicHeight,
            isEditable: true,
            onDone: onCommit
        )
            .frame(minHeight: dynamicHeight, maxHeight: dynamicHeight)
            .background(placeholderView, alignment: .topLeading)
    }

    var placeholderView: some View {
        Group {
            if showingPlaceholder {
                Text(placeholder).foregroundColor(.gray)
                    .padding(.leading, 4)
                    .padding(.top, 8)
            }
        }
    }
}
