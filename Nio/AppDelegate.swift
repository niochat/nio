import UIKit
import MatrixSDK
import class NioKit.AccountManager

class AppDelegate: NSObject, UIApplicationDelegate {
    func applicationDidFinishLaunching(_ application: UIApplication) {}

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool
    {
        if let notificationData = launchOptions?[.remoteNotification] as? [String: AnyObject],
           let aps = notificationData["aps"] as? [String: AnyObject]
        {
            // TODO: Deeplink into relevant conversation
            print(aps)
        }

        return true
    }
}

// MARK: Notifications

extension AppDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        AccountManager.shared.deviceToken = deviceToken.map { String(format: "%.02.2hhx", $0) }.joined()
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Error registering for notifications: \(error)")
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let aps = userInfo["aps"] as? [String: AnyObject] else {
            completionHandler(.failed)
            return
        }
        guard let alert = aps["alert"] as? [String: AnyObject],
              let title = alert["title"] as? String,
              let body = alert["body"] as? String
        else {
            completionHandler(.failed)
            return
        }
        showLocalNotification(title: title, body: body)
        completionHandler(.noData)
    }

    private func showLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = ""
        content.body = body
//        content.badge = count as NSNumber

        // FIXME: This doesn't appear to work
        let request = UNNotificationRequest(identifier: "chat.nio.local-notification", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

//    func clearNotification() {
//        UIApplication.shared.applicationIconBadgeNumber = 0
//        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
//        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
//    }
}
