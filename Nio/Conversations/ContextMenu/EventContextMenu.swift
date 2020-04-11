import SwiftUI
import SwiftMatrixSDK

private struct EventContextMenuViewModel {
    var canReact: Bool
    var canReply: Bool
    var canEdit: Bool
    var canRedact: Bool

    init(event: MXEvent, userId: String) {
        var canReact = false
        var canReply = false
        var canEdit = false
        var canRedact = false

        // The correct way to check if replying is possible is `-[MXRoom canReplyToEvent:]`.

        let reactableEvents = [
            kMXEventTypeStringRoomMessage
        ]

        if reactableEvents.contains(event.type) {
            canReact = true
//            canReply = true
        }

        // TODO: Redacting messages is a powerlevel thing, you can't only redact your own.
        if event.sender == userId
            && reactableEvents.contains(event.type)
            && !event.isRedactedEvent() {
//            canEdit = true
            canRedact = true
        }

        self.canReact = canReact
        self.canReply = canReply
        self.canEdit = canEdit
        self.canRedact = canRedact
    }
}

struct EventContextMenu: View {
    private var model: EventContextMenuViewModel

    typealias Action = () -> Void

    var onReact: Action
    var onReply: Action
    var onEdit: Action
    var onRedact: Action

    init(model: EventContextMenuModel) {
        self.init(event: model.event,
                  userId: model.userId,
                  onReact: model.onReact,
                  onReply: model.onReply,
                  onEdit: model.onEdit,
                  onRedact: model.onRedact)
    }

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
                    Text(L10n.Event.ContextMenu.addReaction)
                    Image(systemName: "smiley")
                })
            }
            if model.canReply {
                Button(action: onReply, label: {
                    Text(L10n.Event.ContextMenu.reply)
                    Image(systemName: "arrowshape.turn.up.left")
                })
            }
            if model.canEdit {
                Button(action: onEdit, label: {
                    Text(L10n.Event.ContextMenu.edit)
                    Image(systemName: "pencil")
                })
            }
            if model.canRedact {
                Button(action: onRedact, label: {
                    Text(L10n.Event.ContextMenu.remove)
                    Image(systemName: "trash")
                })
            }
        }
    }
}
