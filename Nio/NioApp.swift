import SwiftUI
import NioKit

@main
struct NioApp: App {
    @StateObject var accountStore = AccountStore()
    @StateObject var appSettings = AppSettings()

    @AppStorage("accentColor") var accentColor: Color = .purple

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(accountStore)
                .environmentObject(appSettings)
                .accentColor(accentColor)
        }
    }
}
