import SwiftUI
import class SwiftMatrixSDK.MXEvent

struct RoomNameEventView: View {
    struct ViewModel {
        let sender: String
        let newName: String
        let oldName: String?

        init(event: MXEvent) {
            self.sender = event.sender ?? ""
            self.newName = event.content(valueFor: "name") ?? "unknown"
            self.oldName = event.prevContent(valueFor: "name")
        }

        init(sender: String, newName: String, oldName: String?) {
            self.sender = sender
            self.newName = newName
            self.oldName = oldName
        }
    }

    var model: ViewModel

    var body: some View {
        if let oldName = model.oldName {
            return GenericEventView(text: "\(model.sender) changed the room name from \(oldName) to \(model.newName)")
        }
        return GenericEventView(text: "\(model.sender) changed the room name to \(model.newName)")
    }
}

struct RoomNameEventView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            RoomNameEventView(model: .init(sender: "Jane", newName: "New Room", oldName: nil))
            RoomNameEventView(model: .init(sender: "Jane", newName: "New Room", oldName: "Old Room"))
        }
        .previewLayout(.sizeThatFits)
    }
}
