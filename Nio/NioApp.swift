import SwiftUI
import NioKit

@main
struct NioApp: App {
    @StateObject var accountStore = AccountStore()

    @AppStorage("accentColor") var accentColor: Color = .purple

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(accountStore)
                .accentColor(accentColor)
        }
    }
}
