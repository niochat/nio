import SwiftUI
import MatrixSDK

struct EventContextMenuModel {
    typealias Action = () -> Void

    var event: MXEvent
    var userId: String

    var onReact: Action
    var onReply: Action
    var onEdit: Action
    var onRedact: Action
}

extension EventContextMenuModel {
    static var previewModel: EventContextMenuModel {
        EventContextMenuModel(event: MXEvent(), userId: "Jane", onReact: {}, onReply: {}, onEdit: {}, onRedact: {})
    }
}
