import SwiftUI
import NioKit

@main
struct NioApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    #endif

    @StateObject private var accountStore = AccountStore()

    @AppStorage("accentColor") private var accentColor: Color = .purple

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(accountStore)
                .accentColor(accentColor)
        }
    }
}
