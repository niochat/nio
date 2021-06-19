//
//  AppDelegate.swift
//  Nio
//
//  Created by Finn Behrens on 15.06.21.
//  Copyright © 2021 Kilian Koeltzsch. All rights reserved.
//

import Foundation
import NioIntentsExtension
import MatrixSDK
import Intents
import UserNotifications
import UIKit
import NioKit

class AppDelegate: NSObject, UIApplicationDelegate, ObservableObject {
    public static let shared = AppDelegate()
    
    @Published
    var selectedRoom: MXRoom.MXRoomId?
    
    var isPushAllowed: Bool = false
    
    func application(_ application: UIApplication,
                     willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("willFinishLaunschingWithOptions")
        
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = self
        return true
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        let notificationCenter = UNUserNotificationCenter.current()
        
        self.createMessageActions(notificationCenter: notificationCenter)
        
        async {
            do {
                let state = try await notificationCenter.requestAuthorization(options: [.badge, .sound, .alert])
                Self.shared.isPushAllowed = state
                application.registerForRemoteNotifications()
            } catch {
                print("error requesting UNUserNotificationCenter: \(error.localizedDescription)")
            }
        }
        
        print("Your code here")
        return true
    }
    
    func application(_ application: UIApplication,
                     handlerFor intent: INIntent) -> Any? {
        print("intent")
        print(intent)
        //return IntentHandler()
        return nil
    }
    
    // TODO: remove?? (should have been replaced by swiftui)
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        print("userActivity")
        print(userActivity.activityType)
        switch userActivity.activityType {
        case "chat.nio.chat":
            if let id = userActivity.userInfo?["id"] as? String {
                print("restoring room \(id)")
                Self.shared.selectedRoom = MXRoom.MXRoomId(id)
                return true
            }
        default:
            print("cannot handle type \(userActivity.activityType)")
        }
        return true
        //return false
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})
        print("this will return '32 bytes' in iOS 13+ rather than the token \(tokenString)")
        async {
            do {
                try await AccountStore.shared.setPusher(key: deviceToken)
                print("set pusher")
            } catch {
                print("could not set pusher: \(error.localizedDescription)")
            }
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("error registering token: \(error.localizedDescription)")
    }
}


 
 // Conform to UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    
    /*func userNotificationCenter(_ center: UNUserNotificationCenter,
           willPresent notification: UNNotification,
           withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        
        print("got notification: \(notification)")
        // TODO: does not seem to work, and also only do that for nio.chat.developer-settings.*
        //UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notification.request.identifier])
        //UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notification.request.identifier])
        
        completionHandler([.banner, .sound])
    }*/
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        print("got notification \(notification)")
        
        return [.banner, .sound]
    }
    
    @MainActor
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let store = AccountStore.shared
        print("did receive: \(response.actionIdentifier)")
        
        while store.loginState.isAuthenticating {
            usleep(2000)
            print("logging in")
        }
        
        let roomId = MXRoom.MXRoomId(response.notification.request.content.userInfo["room_id"] as? String ?? "")
        let room = store.findRoom(id: roomId)
        let eventId = MXEvent.MXEventId(response.notification.request.content.userInfo["event_id"] as? String ?? "")
       
        let actionIdentifier = response.actionIdentifier
        if actionIdentifier.starts(with: "chat.nio.reaction.emoji") {
            guard let room = room else {
                return
            }
            let emoji: String
            switch actionIdentifier {
            case "chat.nio.reaction.emoji.like":
                emoji = "👍"
            case "chat.nio.reaction.emoji.dislike":
                emoji = "👎"
            default:
                print("invalid emoji ")
                return
            }
            print("reacting with \(emoji)")
            await room.react(toEvent: eventId, emoji: emoji)
        } else if actionIdentifier == "chat.nio.reaction.msg" {
            guard let room = room else {
                return
            }
            if let textResponse = response as? UNTextInputNotificationResponse {
                let text = textResponse.userText
                
                do {
                    // TODO: parse markdown to html
                    let replyContent = try await  room.createReply(toEventId: eventId, text: text)
                    await room.sendEvent(.roomMessage, content: replyContent)
                } catch {
                    print("could not reply to event: \(error.localizedDescription)")
                }
                // TODO: proper reply
                //await room?.send(text: text)
            }
        } else {
            print("unknown actionIdentifier: \(actionIdentifier)")
        }
       
        
        return
    }
    
}

extension AppDelegate {
    func createMessageActions(notificationCenter: UNUserNotificationCenter) {
        let likeAction = UNNotificationAction(identifier: "chat.nio.reaction.emoji.like", title: "like", options: [], icon: UNNotificationActionIcon(systemImageName: "hand.thumbsup"))
        // TODO: is this destructive??
        let dislikeAction = UNNotificationAction(identifier: "chat.nio.reaction.emoji.dislike", title: "dislike", options: [], icon: UNNotificationActionIcon(systemImageName: "hand.thumbsdown"))
        
        // TODO: textinput
        let textInputAction = UNTextInputNotificationAction(identifier: "chat.nio.reaction.msg", title: "Message", options: .authenticationRequired, icon: UNNotificationActionIcon(systemImageName: "text.bubble"), textInputButtonTitle: "Reply", textInputPlaceholder: "Message")
        
        // TODO: intentIdentifiers
        let messageReplyAction = UNNotificationCategory(identifier: "chat.nio.messageReplyAction", actions: [likeAction, dislikeAction, textInputAction], intentIdentifiers: [], options: [.allowInCarPlay, .hiddenPreviewsShowTitle, .hiddenPreviewsShowSubtitle])
        
        notificationCenter.setNotificationCategories([messageReplyAction])
    }
}
