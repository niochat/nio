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
    public var avatarUrlAbsolute: URL? {
        get async {
            guard let avatar = (self.avatarUrl ?? nil) else {
                return nil
            }

            if avatar.starts(with: "http") {
                return URL(string: avatar)
            }

            if let mxUrl = await AccountStore.shared.session?.mediaManager.url(ofContent: avatar),
               let url = URL(string: mxUrl) {
                return url
            } else {
                return URL(string: avatar)
            }
        }
    }
    
    var inPerson: INPerson {
        get async {
            //let imageUrl = await self.avatarUrlAbsolute
            let imageUrl = URL(string: "https://upload.wikimedia.org/wikipedia/commons/4/47/PNG_transparency_demonstration_1.png")
            let inImage = imageUrl.flatMap({ INImage(url: $0) })
            //let inImage = imageUrl.flatMap({ INImage(url: $0, width: 50, height: 50) })
            
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
    
    func inPerson(isMe: Bool = false) async -> INPerson {
        let imageUrl = URL(string: "https://upload.wikimedia.org/wikipedia/commons/4/47/PNG_transparency_demonstration_1.png")
        let inImage = imageUrl.flatMap({ INImage(url: $0) })
        
        return INPerson(
            personHandle: INPersonHandle(value: self.userId, type: .unknown),
            nameComponents: nil, // TODO
            displayName: self.displayname,
            image: inImage,
            contactIdentifier: nil,
            customIdentifier: self.userId,
            isMe: isMe,
            suggestionType: .instantMessageAddress
        )
    }
}

extension MXRoomMembers {
    var inPerson: [INPerson] {
        get async {
            //await self.members.map { await $0.inPerson }
            var inPerson: [INPerson] = []
            for member in self.members {
                inPerson.append(await member.inPerson)
            }
            return inPerson
        }
    }
}
