import SwiftUI
import class MatrixSDK.MXEvent

struct RoomNameEventView: View {
    struct ViewModel {
        fileprivate let sender: String
        fileprivate let newName: String
        fileprivate let oldName: String?

        init(event: MXEvent) {
            self.sender = event.sender ?? ""
            self.newName = event.content(valueFor: "name") ?? L10n.Event.unknownRoomNameFallback
            self.oldName = event.prevContent(valueFor: "name")
        }

        init(sender: String, newName: String, oldName: String?) {
            self.sender = sender
            self.newName = newName
            self.oldName = oldName
        }
    }

    let model: ViewModel

    var body: some View {
        if let oldName = model.oldName {
            return GenericEventView(text: L10n.Event.RoomName.changeName(model.sender, oldName, model.newName))
        }
        return GenericEventView(text: L10n.Event.RoomName.setName(model.sender, model.newName))
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
