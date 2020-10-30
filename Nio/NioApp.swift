import SwiftUI

@main
struct NioApp: App {
    @StateObject var accountStore = AccountStore()
    @StateObject var appSettings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(accountStore)
                .environmentObject(appSettings)
                .accentColor(appSettings.accentColor)
        }
    }
}
