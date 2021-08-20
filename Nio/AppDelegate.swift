//
//  AppDelegate.swift
//  AppDelegate
//
//  Created by Finn Behrens on 20.08.21.
//  Copyright © 2021 Kilian Koeltzsch. All rights reserved.
//

import Foundation
import UIKit

import MatrixSDK

import NioKit

@MainActor
class AppDelegate: NSObject, UIApplicationDelegate, ObservableObject {
    public static var shared = AppDelegate();
    
    var isPushAllowed: Bool = false
    
    @Published
    var deviceToken: String?
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        Self.shared = self
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = self
        return true
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        let notificationCenter = UNUserNotificationCenter.current()
        
        self.createMessageActions(notificationCenter: notificationCenter)
        
        Task.init(priority: .userInitiated) {
            do {
                let state = try await notificationCenter.requestAuthorization(options: [.badge, .sound, .alert])
                self.isPushAllowed = state
                application.registerForRemoteNotifications()
            } catch {
                print("error requesting UNUserNotificationCenter: \(error.localizedDescription)")
            }
            
            // todo: requestSiriAuthorization()
        }
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})
        print("remote notifications token: \(tokenString)")
        self.deviceToken = deviceToken.base64EncodedString()
        // FIXME: dispatch a background process to set the token
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // TODO: show notification to user
        print("error registering token: \(error.localizedDescription)")
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // TODO: render app specific banner instead of os banner
        // TODO: skip if the notification is for the current shown room
        // TODO: special rendering for the preferences notifications
        return [.banner, .sound]
    }
    
    // prepare notification actions
    func createMessageActions(notificationCenter: UNUserNotificationCenter) {
        let likeAction = UNNotificationAction(
            identifier: "chat.nio.reaction.emoji.like",
            title: "like",
            options: [],
            icon: UNNotificationActionIcon(systemImageName: "hand.thumbsup")
        )
        
        // TODO: decide if dislike is a desctructive action, and should get the os tag for desctructive
        let dislikeAction = UNNotificationAction(
            identifier: "chat.nio.reaction.emoji.dislike",
            title: "dislike",
            options: [],
            icon: UNNotificationActionIcon(systemImageName: "hand.thumbsdown")
        )
        
        let replyAction = UNTextInputNotificationAction(
            identifier: "chat.nio.reaction.msg",
            title: "Message",
            options: .authenticationRequired,
            icon: UNNotificationActionIcon(systemImageName: "text.bubble"),
            textInputButtonTitle: "Reply",
            textInputPlaceholder: "Message"
        )
        
        let messageReplyAction = UNNotificationCategory(
            identifier: "chat.nio.message.reply",
            actions: [likeAction, dislikeAction, replyAction],
            intentIdentifiers: [],
            options: [.allowInCarPlay, .hiddenPreviewsShowTitle]
        )
        
        notificationCenter.setNotificationCategories([messageReplyAction])
    }
}
