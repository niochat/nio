import SwiftUI

struct MessageComposerView: View {
    @State private var message = ""

    typealias SendHandler = (String) -> Void
    var sendHandler: (SendHandler)?
    func onSend(handler: @escaping SendHandler) -> Self {
        var copy = self
        copy.sendHandler = handler
        return copy
    }

    var body: some View {
        HStack {
            TextField("Message...", text: $message)
            Button(action: {
                self.sendHandler?(self.message)
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
    }
}

struct MessageComposerView_Previews: PreviewProvider {
    static var previews: some View {
        MessageComposerView()
            .accentColor(.purple)
            .previewLayout(.sizeThatFits)
    }
}
