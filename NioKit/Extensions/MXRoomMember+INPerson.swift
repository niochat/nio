//
//  MXRoomMember+INPerson.swift
//  Masui
//
//  Created by Finn Behrens on 11.06.21.
//

import Foundation
import Intents
import MatrixSDK

extension MXRoomMember {
    var inPerson: INPerson {
        let inImage = self.avatarUrl.flatMap { avatar in
            URL(string: avatar)
        }.flatMap { url in
            INImage(url: url)
        }
        return INPerson(
            personHandle: INPersonHandle(value: self.userId, type: .unknown),
            nameComponents: nil, // TODO
            displayName: self.displayname,
            image: inImage,
            contactIdentifier: nil,
            customIdentifier: self.userId,
            isMe: false,
            suggestionType: .instantMessageAddress
        )
    }
}

extension MXRoomMembers {
    var inPerson: [INPerson] {
        self.members.map { $0.inPerson }
    }
}
