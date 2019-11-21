import SwiftUI

struct MessageComposerView: View {
    @Environment (\.colorScheme) var colorScheme

    @Binding var message: String

    var onCommit: () -> Void

    var body: some View {
        HStack {
            Button(action: {

            }, label: {
                Image(systemName: "plus")
                    .font(.system(size: 20))
            })

            ZStack {
                Capsule(style: .continuous)
                    .frame(height: 40)
                    .foregroundColor(colorScheme == .light ? Color(#colorLiteral(red: 0.9332506061, green: 0.937307477, blue: 0.9410644174, alpha: 1)) : Color(#colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)))

                TextField("New Message...", text: $message, onCommit: onCommit)
                    .padding(.horizontal)
            }

            Button(action: {
                self.onCommit()
            }, label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
            })
            .disabled(message.isEmpty)
        }
    }
}

struct MessageComposerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MessageComposerView(message: .constant(""), onCommit: {})
                .padding()
                .environment(\.colorScheme, .light)

            ZStack {
                Color.black.frame(height: 80)
                MessageComposerView(message: .constant(""), onCommit: {})
                    .padding()
                    .environment(\.colorScheme, .dark)
            }
        }
        .accentColor(.purple)
        .previewLayout(.sizeThatFits)
    }
}
