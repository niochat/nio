import SwiftUI
import SwiftMatrixSDK

private struct EventContextMenuViewModel {
    var canReact: Bool
    var canReply: Bool
    var canEdit: Bool
    var canRedact: Bool

    init(canReact: Bool, canReply: Bool, canEdit: Bool, canRedact: Bool) {
        self.canReact = canReact
        self.canReply = canReply
        self.canEdit = canEdit
        self.canRedact = canRedact
    }

    init(event: MXEvent, userId: String) {
        var canReact = false
        var canReply = false
        var canEdit = false
        var canRedact = false

        // The correct way to check if replying is possible is `-[MXRoom canReplyToEvent:]`.

        let reactableEvents = [
            kMXEventTypeStringRoomMessage
        ]

//        if reactableEvents.contains(event.type) {
//            canReact = true
//            canReply = true
//        }

        if event.sender == userId && reactableEvents.contains(event.type) {
//            canEdit = true
            canRedact = true
        }

        self.init(canReact: canReact,
                  canReply: canReply,
                  canEdit: canEdit,
                  canRedact: canRedact)
    }
}

struct EventContextMenu: View {
    private var model: EventContextMenuViewModel

    typealias Action = () -> Void

    var onReact: Action
    var onReply: Action
    var onEdit: Action
    var onRedact: Action

    init(event: MXEvent,
         userId: String,
         onReact: @escaping Action,
         onReply: @escaping Action,
         onEdit: @escaping Action,
         onRedact: @escaping Action
    ) {
        self.model = EventContextMenuViewModel(event: event, userId: userId)
        self.onReact = onReact
        self.onReply = onReply
        self.onEdit = onEdit
        self.onRedact = onRedact
    }

    var body: some View {
        Group {
            if model.canReact {
                Button(action: onReact, label: {
                    Text("Add Reaction")
                    Image(systemName: "smiley")
                })
            }
            if model.canReply {
                Button(action: onReply, label: {
                    Text("Reply")
                    Image(systemName: "arrowshape.turn.up.left")
                })
            }
            if model.canEdit {
                Button(action: onEdit, label: {
                    Text("Edit")
                    Image(systemName: "pencil")
                })
            }
            if model.canRedact {
                Button(action: onRedact, label: {
                    Text("Redact")
                    Image(systemName: "trash")
                })
            }
        }
    }
}
