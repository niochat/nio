import SwiftUI
import NioKit

@main
struct NioApp: App {
    @StateObject private var accountStore = AccountStore()

    @AppStorage("accentColor") private var accentColor: Color = .purple

    var body: some Scene {
        WindowGroup {
          #if os(macOS)
            RootView()
                .environmentObject(accountStore)
                .accentColor(accentColor)
                .frame(minWidth: Style.minWindowWidth, minHeight: Style.minWindowHeight)
                .presentedWindowToolbarStyle(UnifiedWindowToolbarStyle(showsTitle: false))
          #else
            RootView()
                .environmentObject(accountStore)
                .accentColor(accentColor)
          #endif
        }
    }
}

#if os(macOS)
enum Style {
    static let minSidebarWidth  = 280 as CGFloat
    static let minTimelineWidth = 480 as CGFloat
    static let minWindowWidth   = minSidebarWidth + minTimelineWidth + 10
    static let minWindowHeight  = 320 as CGFloat
}
#endif
