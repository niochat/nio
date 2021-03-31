import SwiftUI

struct ExDivider: View {
    let color: Color = .accentColor
    let width: CGFloat = 3
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: width)
            .edgesIgnoringSafeArea(.horizontal)
    }
}

struct MessageComposerView: View {
    @Environment (\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.sizeCategory) private var sizeCategory

    @AppStorage("iconPack") private var iconPack: String = "Default (nio)"

    @Binding var showAttachmentPicker: Bool

    @Binding var isEditing: Bool

    @State private var contentSizeThatFits: CGSize = .zero

    @Binding var attributedMessage: NSAttributedString

    var highlightMessage: String?

    let onCancel: () -> Void
    let onCommit: () -> Void

    private var backgroundColor: Color {
        colorScheme == .light ? Color(#colorLiteral(red: 0.9332506061, green: 0.937307477, blue: 0.9410644174, alpha: 1)) : Color(#colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1))
    }

    private var gradient: LinearGradient {
        let color: Color = backgroundColor
        let colors: [Color]
        if colorScheme == .dark {
            colors = [color.opacity(1.0), color.opacity(0.85)]
        } else {
            colors = [color.opacity(0.85), color.opacity(1.0)]
        }
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 10.0 * sizeCategory.scalingFactor)
            .fill(gradient).opacity(0.9)
    }

    private var messageEditorHeight: CGFloat {
      #if os(macOS)
        return min(self.contentSizeThatFits.height, 240)
      #else
        return min(
            self.contentSizeThatFits.height,
            0.25 * UIScreen.main.bounds.height
        )
      #endif
    }

    private var highlightMessageView: some View {
        Group {
            Divider()
            HStack {
                ExDivider()
                    .background(Color.accentColor)
                VStack {
                    HStack {
                        Text(verbatim: L10n.Composer.editMessage)
                            .frame(alignment: .leading)
                            .padding(.leading, 10)
                            .foregroundColor(.accentColor)
                        Spacer()
                        Button(action: {
                            self.onCancel()
                        }, label: {
                            SFSymbol.close
                                .font(.system(size: 20))
                                .accessibility(label: Text(verbatim: L10n.Composer.AccessibilityLabel.cancelEdit))
                        })
                    }
                    Text(highlightMessage!)
                        .lineLimit(2)
                        .padding([.horizontal, .bottom], 10)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: Alignment.leading)
                }
            }.fixedSize(horizontal: false, vertical: true)
        }
    }

    private var attachmentPickerButton: some View {
        Button(action: {
            self.showAttachmentPicker.toggle()
        }, label: {
            IconPack(title: iconPack).pack.getIconAttachment
        })
    }

    var messageEditorView: some View {
        #if os(macOS)
            let textAttributes = TextAttributes()
        #else
            let textAttributes = TextAttributes(autocapitalizationType: .sentences)
        #endif
        return MultilineTextField(
            attributedText: $attributedMessage,
            placeholder: L10n.Composer.newMessage,
            isEditing: self.$isEditing,
            textAttributes: textAttributes,
            onCommit: onCommit
        )
        .background(self.background)
        .onPreferenceChange(ContentSizeThatFitsKey.self) {
            self.contentSizeThatFits = $0
        }
        .frame(height: self.messageEditorHeight)
    }

    private var sendButton: some View {
        Button(action: {
            self.onCommit()
        }, label: {
            IconPack(title: iconPack).pack.getIconSendMessage
        })
        .disabled(attributedMessage.isEmpty)
    }

    var body: some View {
        VStack {
            if self.highlightMessage != nil {
                self.highlightMessageView
            }
            HStack {
                self.attachmentPickerButton
                self.messageEditorView
                self.sendButton
            }
        }
    }
}

struct MessageComposerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MessageComposerView(
                showAttachmentPicker: .constant(false),
                isEditing: .constant(false),
                attributedMessage: .constant(NSAttributedString(string: "New message...")),
                onCancel: {},
                onCommit: {}
            )
            .padding()
            .environment(\.colorScheme, .light)
            ZStack {
                MessageComposerView(
                    showAttachmentPicker: .constant(false),
                    isEditing: .constant(false),
                    attributedMessage: .constant(NSAttributedString(string: "New message...")),
                    highlightMessage: "Message to edit",
                    onCancel: {},
                    onCommit: {}
                )
                .padding()
                .environment(\.colorScheme, .light)
            }
            ZStack {
                Color.black.frame(height: 80)
                MessageComposerView(
                    showAttachmentPicker: .constant(false),
                    isEditing: .constant(false),
                    attributedMessage: .constant(NSAttributedString(string: "New message...")),
                    onCancel: {},
                    onCommit: {}
                )
                .padding()
                .environment(\.colorScheme, .dark)
            }
            ZStack {
                Color.black.frame(height: 152)
                MessageComposerView(
                    showAttachmentPicker: .constant(false),
                    isEditing: .constant(false),
                    attributedMessage: .constant(NSAttributedString(string: "New message...")),
                    highlightMessage: "Message to edit",
                    onCancel: {},
                    onCommit: {}
                )
                .padding()
                .environment(\.colorScheme, .dark)
            }
        }
        .accentColor(.purple)
        .previewLayout(.sizeThatFits)
    }
}
