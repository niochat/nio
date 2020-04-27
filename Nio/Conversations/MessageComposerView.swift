import SwiftUI

struct MessageComposerView: View {
    @Environment (\.colorScheme) var colorScheme
    @Environment(\.sizeCategory) var sizeCategory

    @Binding var message: String
    @Binding var showAttachmentPicker: Bool

    var onCommit: () -> Void

    var highlightMessage: String?
    @Binding var highlightMessageToggle: Bool

    var background: some View {
        let radius: CGFloat = 15.0 * sizeCategory.scalingFactor
        return RoundedRectangle(cornerRadius: radius)
            .fill(colorScheme == .light ? Color(#colorLiteral(red: 0.9332506061, green: 0.937307477, blue: 0.9410644174, alpha: 1)) : Color(#colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)))
    }

    var body: some View {
        VStack {
            if self.highlightMessageToggle {
                HStack {
                    Button(action: {
                        self.highlightMessageToggle.toggle()
                    }, label: {
                        Image(systemName: "multiply")
                            .font(.system(size: 20))
                            .accessibility(label: Text(L10n.Composer.AccessibilityLabel.sendFile))
                    })
                    Text(highlightMessage!)
                        .padding(10)
                        .background(background)
                }
            }
            HStack {
                Button(action: {
                    self.showAttachmentPicker.toggle()
                }, label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 20))
                        .accessibility(label: Text(L10n.Composer.AccessibilityLabel.sendFile))
                })

                ZStack {
                    Capsule(style: .continuous)
                        .frame(height: 40)
                        .foregroundColor(colorScheme == .light ? Color(#colorLiteral(red: 0.9332506061, green: 0.937307477, blue: 0.9410644174, alpha: 1)) : Color(#colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)))

                    TextField(L10n.Composer.newMessage, text: $message, onCommit: onCommit)
                        .padding(.horizontal)
                }

                Button(action: {
                    self.onCommit()
                }, label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                        .accessibility(label: Text(L10n.Composer.AccessibilityLabel.send))
                })
                .disabled(message.isEmpty)
            }
        }
    }
}

struct MessageComposerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MessageComposerView(message: .constant(""),
                                showAttachmentPicker: .constant(false),
                                onCommit: {}, highlightMessageToggle: .constant(false))
                .padding()
                .environment(\.colorScheme, .light)

            ZStack {
                Color.black.frame(height: 80)
                MessageComposerView(message: .constant(""),
                                    showAttachmentPicker: .constant(false),
                                    onCommit: {}, highlightMessageToggle: .constant(false))
                    .padding()
                    .environment(\.colorScheme, .dark)
            }
        }
        .accentColor(.purple)
        .previewLayout(.sizeThatFits)
    }
}
