//
//  ReplyEvent.swift
//  Nio
//
//  Created by Finn Behrens on 19.06.21.
//  Copyright © 2021 Kilian Koeltzsch. All rights reserved.
//

import Foundation
import MatrixSDK

struct ReplyEvent {
    let eventId: MXEvent.MXEventId
    let roomId: MXRoom.MXRoomId
    let sender: String
    let text: String
    let textHtml: String?
    let replyText: String?
    let replyTextHtml: String?
    
    init(eventId: MXEvent.MXEventId, roomId: MXRoom.MXRoomId, sender: String, text: String, textHtml: String? = nil, replyText: String?, replyTextHtml: String? = nil) {
        self.eventId = eventId
        self.roomId = roomId
        self.sender = sender
        self.text = text
        self.textHtml = textHtml
        self.replyText = replyText
        self.replyTextHtml = replyTextHtml
    }
    
}

extension ReplyEvent: CustomEvent {
    func encodeContent() throws -> [String: Any] {
        let replyText = self.replyTextHtml ?? self.replyText ?? ""
        let text = self.textHtml ?? self.text

        let bodyText: String
        if let replyText = self.replyText {
            bodyText = "> " + replyText + "\n" + self.text
        } else {
            bodyText = self.text
        }
                
        // TODO: via in roomId.getMatrixToLink
        let formattedBody = "<mx-reply><blockquote><a href=\"\(self.eventId.getMatrixToLink(self.roomId))\">In reply to</a> <a href=\"https://matrix.to/#/\(self.sender)\"</a><br>\(replyText)</blockquote></mx-reply>\(text)"
        
        
        let content: [String: Any] = [
            "msgtype": kMXMessageTypeText,
            "body": bodyText,
            "format": kMXRoomMessageFormatHTML,
            "formatted_body": formattedBody,
            "m.relates_to": [
                "m.in_reply_to": [
                    "event_id": eventId.id
                ]
            ]
        ]
        
        
        return content
    }
}

extension MXEvent.MXEventId {
    func getMatrixToLink(_ roomId: MXRoom.MXRoomId) -> String {
        return "https://matrix.to/#/\(roomId.id)/\(self.id)"
    }
}

extension MXRoom.MXRoomId {
    func getMatrixToLink() -> String {
        return "https://matrix.to/#/\(self.id)"
    }
}

extension MXEvent {
    func createReply(text: String, htmlText: String? = nil) -> ReplyEvent {
        let body = self.content["body"] as? String
        let formattedBody = self.content["formatted_body"] as? String
        
        return ReplyEvent(eventId: self.id, roomId: MXRoom.MXRoomId(self.roomId), sender: self.sender, text: text, textHtml: htmlText, replyText: body, replyTextHtml: formattedBody)
    }
}
