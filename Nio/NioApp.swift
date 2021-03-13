import SwiftUI
import NioKit

@main
struct NioApp: App {
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
