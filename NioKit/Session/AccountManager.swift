import Foundation
import UIKit
import SwiftUI
import MatrixSDK

public final class AccountManager {
    var accounts: [AccountStore] = []

    public var deviceToken: String? {
        didSet {
            guard deviceToken != nil else { return }
            UserDefaults.standard.set(deviceToken, forKey: "pushDeviceToken")
            self.accounts.forEach(setPushRule(for:))
        }
    }

    public static var shared = AccountManager()
    private init() {
        self.deviceToken = UserDefaults.standard.string(forKey: "pushDeviceToken")
    }

    func register(_ account: AccountStore) {
        if self.accounts.isEmpty {
            self.requestNotificationAuthorization()
        }
        self.accounts.append(account)
        if deviceToken != nil {
            addPushRules(for: account)
        }
    }

    func deregister(_ account: AccountStore) {
        self.accounts.removeAll { $0.credentials == account.credentials }
    }

    func addPushRules(for account: AccountStore) {
//        account.client?.addPushRule(
//            ruleId: <#T##String#>,
//            scope: <#T##MXPushRuleScope#>,
//            kind: <#T##MXPushRuleKind#>,
//            actions: <#T##[Any]#>,
//            pattern: <#T##String#>,
//            conditions: <#T##[[String : Any]]#>,
//            completion: <#T##(MXResponse<Void>) -> Void#>)
    }

    func setPushRule(for account: AccountStore) {
//        account.client?.setPusher(
//            pushKey: <#T##String#>,
//            kind: <#T##MXPusherKind#>,
//            appId: <#T##String#>,
//            appDisplayName: <#T##String#>,
//            deviceDisplayName: <#T##String#>,
//            profileTag: <#T##String#>,
//            lang: <#T##String#>,
//            data: <#T##[String : Any]#>,
//            append: <#T##Bool#>,
//            completion: <#T##(MXResponse<Void>) -> Void#>)
    }

    func removePushRules(for account: AccountStore) {
//        account.client?.removePushRule(
//            ruleId: <#T##String#>,
//            scope: <#T##MXPushRuleScope#>,
//            kind: <#T##MXPushRuleKind#>,
//            completion: <#T##(MXResponse<Void>) -> Void#>)
    }

    func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            self.registerForRemoteNotifications()
        }
    }

    func registerForRemoteNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}
