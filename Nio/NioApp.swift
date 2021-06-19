import SwiftUI
import NioKit
import MatrixSDK
import Intents

@main
struct NioApp: App {
    #if os(macOS)
    #else
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    @StateObject private var accountStore = AccountStore.shared
    
    //@State private var selectedRoomId: ObjectIdentifier?

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
                .onContinueUserActivity("chat.nio.chat", perform: {activity in
                    print("handling activity: \(activity)")
                    if let id = activity.userInfo?["id"] as? String {
                        print("restored room: \(id)")
                        AppDelegate.shared.selectedRoom = MXRoom.MXRoomId(id)
                    }
                    /*if let id = activity.userInfo?["id"] as? String {
                        print("found string \(id)")
                    }*/
                })
                .onAppear {
                    async {
                        let _: INSiriAuthorizationStatus = await withCheckedContinuation {continuation in
                            INPreferences.requestSiriAuthorization({status in
                                continuation.resume(returning: status)
                            })
                        }
                    }
                }
          #endif
        }
      
      #if os(macOS)
        Settings {
            SettingsContainerView()
                .environmentObject(accountStore)
        }
      #endif
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
