import SwiftUI
import SwiftMatrixSDK

struct RecentRoomsContainerView: View {
    @EnvironmentObject var store: AccountStore
    @EnvironmentObject var settings: AppSettings

    @State private var selectedNavigationItem: SelectedNavigationItem?

    var body: some View {
        RecentRoomsView(selectedNavigationItem: $selectedNavigationItem,
                        rooms: store.rooms)
            .sheet(item: $selectedNavigationItem) {
                NavigationSheet(selectedItem: $0)
                    // This really shouldn't be necessary. SwiftUI bug?
                    .environmentObject(self.store)
                    .environmentObject(self.settings)
                    .accentColor(self.settings.accentColor)
            }
            .onAppear {
                self.store.startListeningForRoomEvents()
            }
    }
}

struct RecentRoomsView: View {
    @Binding fileprivate var selectedNavigationItem: SelectedNavigationItem?

    var rooms: [NIORoom]

    var settingsButton: some View {
        Button(action: {
            self.selectedNavigationItem = .settings
        }, label: {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 25))
                .accessibility(label: Text(L10n.RecentRooms.AccessibilityLabel.settings))
        })
    }

    var newConversationButton: some View {
        Button(action: {
            self.selectedNavigationItem = .newMessage
        }, label: {
            Image(systemName: "plus")
                .font(.system(size: 25))
                .accessibility(label: Text(L10n.RecentRooms.AccessibilityLabel.newConversation))
        })
    }

    var body: some View {
        NavigationView {
            List(rooms) { room in
                NavigationLink(destination: RoomContainerView(room: room)) {
                    RoomListItemContainerView(room: room)
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
                SettingsContainerView()
            )
        case .newMessage:
            return AnyView(
                Text(L10n.RecentRooms.newMessagePlaceholder)
            )
        }
    }
}

struct RecentRoomsView_Previews: PreviewProvider {
    static var previews: some View {
        RecentRoomsView(selectedNavigationItem: .constant(nil), rooms: [])
    }
}
