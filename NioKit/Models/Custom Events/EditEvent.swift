import Foundation
import MatrixSDK

struct EditEvent {
    let eventId: String
    let text: String
}

extension EditEvent: CustomEvent {
    func encodeContent() throws -> [String: Any] {
        [
            "body": "*" + text,
            "m.new_content": [
                "body": text,
                "msgtype": kMXMessageTypeText
            ],
            "m.relates_to": [
                "event_id": eventId,
                "rel_type": MXEventRelationTypeReplace
            ],
            "msgtype": kMXMessageTypeText
        ]
    }
}
