import SwiftUI

struct MessageComposerView: View {
    @State private var message = ""

    var body: some View {
        HStack {
            TextField("Message...", text: $message)
            Button(action: {
                messages.append(StubMessage(id: messages.count, sender: "Neo", message: self.message))
                self.message = ""
            }, label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
            })
            .disabled(message.isEmpty)
        }
        .padding(10)
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.purple, lineWidth: 2)
        )
        .frame(minHeight: 50)
    }
}

struct MessageComposerView_Previews: PreviewProvider {
    static var previews: some View {
        MessageComposerView()
            .accentColor(.purple)
            .previewLayout(.sizeThatFits)
    }
}
