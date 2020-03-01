import SwiftUI
import SwiftMatrixSDK

struct RecentRoomsContainerView: View {
    @EnvironmentObject var store: AccountStore

    @State private var selectedNavigationItem: SelectedNavigationItem?

    var body: some View {
        RecentRoomsView(selectedNavigationItem: $selectedNavigationItem,
                        syncState: $store.syncState,
                        rooms: store.rooms)
            .sheet(item: $selectedNavigationItem) {
                NavigationSheet(selectedItem: $0)
                    // This really shouldn't be necessary. SwiftUI bug?
                    .environmentObject(self.store)
            }
            .onAppear {
                self.store.startListeningForRoomEvents()
            }
    }
}

struct RecentRoomsView: View {
    @Binding fileprivate var selectedNavigationItem: SelectedNavigationItem?

    @Binding var syncState: SyncState
    var rooms: [NIORoom]

    var settingsButton: some View {
        Button(action: {
            self.selectedNavigationItem = .settings
        }, label: {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 25))
                .accessibility(label: Text("Settings"))
        })
    }

    var newConversationButton: some View {
        Button(action: {
            self.selectedNavigationItem = .newMessage
        }, label: {
            Image(systemName: "plus")
                .font(.system(size: 25))
                .accessibility(label: Text("New Conversation"))
        })
    }

    var syncStateBar: some View {
        switch syncState {
        case .synchronized:
            return AnyView(EmptyView())
        case .synchronizing:
            return AnyView(
                ZStack {
                    Color.accentColor.opacity(0.2)
                    HStack {
                        Text("Synchronizing")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(3)
                        ActivityIndicator()
                    }
                }
                .frame(height: 30)
            )
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                syncStateBar
                List(rooms) { room in
                    NavigationLink(destination: RoomContainerView(room: room)) {
                        RoomListItemContainerView(room: room)
                    }
                }
            }
            .navigationBarTitle("Nio", displayMode: .inline)
            .navigationBarItems(leading: settingsButton, trailing: newConversationButton)
        }
    }
}

private enum SelectedNavigationItem: Int, Identifiable {
    case settings
    case newMessage

    var id: Int {
        return self.rawValue
    }
}

private struct NavigationSheet: View {
    var selectedItem: SelectedNavigationItem

    var body: some View {
        switch selectedItem {
        case .settings:
            return AnyView(
                SettingsView()
            )
        case .newMessage:
            return AnyView(
                Text("New Message")
            )
        }
    }
}

struct RecentRoomsView_Previews: PreviewProvider {
    static var previews: some View {
        RecentRoomsView(selectedNavigationItem: .constant(nil), syncState: .constant(.synchronizing), rooms: [])
    }
}
