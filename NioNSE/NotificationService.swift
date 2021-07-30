//
//  NotificationService.swift
//  NioNSE
//
//  Created by Finn Behrens on 18.06.21.
//  Copyright © 2021 Kilian Koeltzsch. All rights reserved.
//

import UserNotifications
import NioKit
import MatrixSDK

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    var contentIntent: UNNotificationContent?

    
    //@MainActor
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        async {
            self.contentHandler = contentHandler
            bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
            
            print("didReceive")
            print(bestAttemptContent?.userInfo as Any)
            if let bestAttemptContent = bestAttemptContent {
                let store = await AccountStore.shared
                // Modify the notification content here...
                //bestAttemptContent.title = "\(bestAttemptContent.title) [modified]"
                
                while await store.loginState.isAuthenticating {
                    // FIXME: !!!!!!!
                    #warning("this is not good coding!!!!!")
                    await Task.yield()
                    //sleep(1)
                }
                
                //store.session?.crypto.
                
                sleep(1)
                
                let roomId = MXRoom.MXRoomId(bestAttemptContent.userInfo["room_id"] as? String ?? "")
                bestAttemptContent.threadIdentifier = roomId.id
                bestAttemptContent.categoryIdentifier = "chat.nio.messageReplyAction"
                let eventId = MXEvent.MXEventId(bestAttemptContent.userInfo["event_id"] as? String ?? "")
                let room = await AccountStore.shared.findRoom(id: roomId)
                bestAttemptContent.subtitle = await !(room?.isDirect ?? false) ? room?.displayName ?? "" : ""
                
                do {
                    //let event = try await store.session?.matrixRestClient.event(withEventId: eventId, inRoom: roomId)
                    let event = try await store.session?.event(withEventId: eventId, inRoom: roomId)
                    guard let event = event else {
                        print("did not find an event")
                        contentHandler(bestAttemptContent)
                        return
                    }
                    print("eventType: \(String(describing: event.type))")
                    print("eventContent: \(String(describing: event.content))")
                    print("error: \(String(describing: event.decryptionError))")
                    

                    
                    if let intent = try await room?.createIntent(event: event) {
                        print(intent.content as Any)
                        print("senderImage: \(intent.sender?.image)")
                        print("keyImage: \(intent.keyImage())")
                        
                        bestAttemptContent.body = intent.content ?? "Message"
                        bestAttemptContent.title = intent.sender?.displayName ?? intent.sender?.customIdentifier ?? ""
                        self.contentIntent = try bestAttemptContent.updating(from: intent)
                        //self.contentIntent = try request.content.updating(from: intent) as! UNMutableNotificationContent
                        //self.contentIntent?.body = intent.content ?? "MESSAGE"
                        
                        
                        print("creatent contentIntent")
                        print(contentIntent!.body)
                        print(contentIntent as Any)
                        if let interaction = try await room?.createNotification(event: event, messageIntent: intent) {
                            try await interaction.donate()
                        }
                    } else {
                        print("did not get an intent")
                    }
                } catch {
                    print("error")
                    print(error.localizedDescription)
                }
                
                print("returning event")
                if let contentIntent = contentIntent {
                    print("found contentIntent")
                    contentHandler(contentIntent)
                } else {
                    print("bestAttemptContent")
                    contentHandler(bestAttemptContent)
                }
                // TODO: exit or not?
                exit(0)
            }
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler {
            if let contentIntent = contentIntent {
                contentHandler(contentIntent)
            }
            else if let bestAttemptContent =  bestAttemptContent {
                contentHandler(bestAttemptContent)
            }
        }
    }
    
    /*
     override func viewDidLoad() {
         print("viewDidLoad")
         super.viewDidLoad()
         // Do any required interface initialization here.
     }
     
     func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
         print("didReceive request")
         //contentHandler()
     }
     
     func didReceive(_ notification: UNNotification) {
         print("didReceive")
         self.label?.text = notification.request.content.body
     }
     */

}
