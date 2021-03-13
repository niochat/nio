import SwiftUI
import MatrixSDK

private struct EventContextMenuViewModel {
    fileprivate let canReact: Bool
    fileprivate let canReply: Bool
    fileprivate let canEdit: Bool
    fileprivate let canRedact: Bool

    init(event: MXEvent, userId: String) {
        var canReact = false
        let canReply = false
        var canEdit = false
        var canRedact = false

        // The correct way to check if replying is possible is `-[MXRoom canReplyToEvent:]`.

        let reactableEvents = [
            kMXEventTypeStringRoomMessage
        ]

        if reactableEvents.contains(event.type ?? "") {
            canReact = true
//            canReply = true
        }

        // TODO: Redacting messages is a powerlevel thing, you can't only redact your own.
        if event.sender == userId
            && reactableEvents.contains(event.type ?? "")
            && !event.isRedactedEvent() {
            canEdit = true
            canRedact = true
        }

        if event.isMediaAttachment() {
            canEdit = false
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

    private let onReact: Action
    private let onReply: Action
    private let onEdit: Action
    private let onRedact: Action

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
                    Text(verbatim: L10n.Event.ContextMenu.addReaction)
                    Image(Asset.Icon.smiley.name)
                        .resizable()
                        .frame(width: 30.0, height: 30.0)
                })
            }
            if model.canReply {
                Button(action: onReply, label: {
                    Text(verbatim: L10n.Event.ContextMenu.reply)
                    Image(Asset.Icon.Arrow.upLeft.name)
                        .resizable()
                        .frame(width: 30.0, height: 30.0)
                })
            }
            if model.canEdit {
                Button(action: onEdit, label: {
                    Text(verbatim: L10n.Event.ContextMenu.edit)
                    Image(Asset.Icon.pencil.name)
                        .resizable()
                        .frame(width: 30.0, height: 30.0)
                })
            }
            if model.canRedact {
                Button(action: onRedact, label: {
                    Text(verbatim: L10n.Event.ContextMenu.remove)
                    Image(Asset.Icon.trash.name)
                        .resizable()
                        .frame(width: 30.0, height: 30.0)
                })
            }
        }
    }
}
