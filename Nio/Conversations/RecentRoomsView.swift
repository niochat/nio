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
    @EnvironmentObject var store: AccountStore

    @Binding fileprivate var selectedNavigationItem: SelectedNavigationItem?

    @State private var showConfirm = false
    @State var deleteId: Int?

    var rooms: [NIORoom]

    var settingsButton: some View {
        Button(action: {
            self.selectedNavigationItem = .settings
        }, label: {
            Image(Asset.Icon.user.name)
                .resizable()
                .frame(width: 30.0, height: 30.0)
                .accessibility(label: Text(L10n.RecentRooms.AccessibilityLabel.settings))
        })
    }

    var newConversationButton: some View {
        Button(action: {
            self.selectedNavigationItem = .newMessage
        }, label: {
            Image(Asset.Icon.addRoom.name)
                .resizable()
                .frame(width: 30.0, height: 30.0)
                .accessibility(label: Text(L10n.RecentRooms.AccessibilityLabel.newConversation))
        })
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(rooms) { room in
                    NavigationLink(destination: RoomContainerView(room: room)) {
                        RoomListItemContainerView(room: room)
                    }
                }
                .onDelete(perform: setDeletIndex)
                }
            .alert(isPresented: $showConfirm) {
                Alert(
                    title: Text("Delete Room"),
                    message: Text("Are you sure you want to delete this room?"),
                    primaryButton: .destructive(
                        Text(L10n.Room.Remove.action),
                        action: {
                            self.delete()
                    }),
                secondaryButton: .cancel())
            }
            .navigationBarTitle("Nio", displayMode: .inline)
            .navigationBarItems(leading: settingsButton, trailing: newConversationButton)
        }
    }

    func setDeletIndex(at offsets: IndexSet) {
        self.showConfirm = true
        for offset in offsets {
            self.deleteId = offset
        }
    }

    func delete() {
        self.store.session?.leaveRoom(self.rooms[self.deleteId!].room.roomId, completion: { _ in
                return
        })
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
