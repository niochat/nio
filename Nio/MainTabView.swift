import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ChatsListView()
                .tabItem {
                    VStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                        Text("Chats")
                    }
                }

            Text("Settings")
                .tabItem {
                    VStack {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                }
        }
        .edgesIgnoringSafeArea(.top)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
