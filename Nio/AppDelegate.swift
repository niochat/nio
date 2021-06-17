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

class AppDelegate: NSObject, UIApplicationDelegate, ObservableObject {
    public static let shared = AppDelegate()
    
    @Published
    var selectedRoom: MXRoom.MXRoomId?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        async {
            do {
                let state = try await UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .sound, .alert])
                print("state: \(state)")
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
}


 
 // Conform to UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
           willPresent notification: UNNotification,
           withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        // TODO: does not seem to work, and also only do that for nio.chat.developer-settings.*
        //UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notification.request.identifier])
        //UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notification.request.identifier])
        
        
        print("userNotificationCenter called")
        completionHandler([.banner, .sound])
    }
    
}
