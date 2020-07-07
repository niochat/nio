import SwiftUI
import SwiftMatrixSDK

import NioKit

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

    var rooms: [NIORoom]

    var joinedRooms: [NIORoom] {
        rooms.filter {$0.room.summary.membership == .join}
    }

    var invitedRooms: [NIORoom] {
        rooms.filter {$0.room.summary.membership == .invite}
    }

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
                if !invitedRooms.isEmpty {
                    RoomsListSection(
                        sectionHeader: L10n.RecentRooms.PendingInvitations.header,
                        rooms: invitedRooms,
                        onLeaveAlertTitle: L10n.RecentRooms.PendingInvitations.Leave.alertTitle
                    )
                }

                RoomsListSection(
                    sectionHeader: nil,
                    rooms: joinedRooms,
                    onLeaveAlertTitle: L10n.RecentRooms.Leave.alertTitle
                )

            }
            .navigationBarTitle("Nio", displayMode: .inline)
            .navigationBarItems(leading: settingsButton, trailing: newConversationButton)
        }
    }

}

struct RoomsListSection: View {
    let sectionHeader: String?
    let rooms: [NIORoom]
    let onLeaveAlertTitle: String

    @State private var showConfirm: Bool = false
    @State private var leaveId: Int?

    private var roomToLeave: NIORoom? {
        guard
            let leaveId = self.leaveId,
            rooms.count > leaveId
        else { return nil }
        return self.rooms[leaveId]
    }

    var sectionContent: some View {
        ForEach(rooms) { room in
            NavigationLink(destination: RoomContainerView(room: room)) {
                RoomListItemContainerView(room: room)
            }
        }
        .onDelete(perform: setLeaveIndex)
    }

    @ViewBuilder
    var section: some View {
        if let sectionHeader = sectionHeader {
            Section(header: Text(sectionHeader)) {
                sectionContent
            }
        } else {
            Section {
                sectionContent
            }
        }
    }

    var body: some View {
        section
        .alert(isPresented: $showConfirm) {
            Alert(
                title: Text(onLeaveAlertTitle),
                message: Text(L10n.RecentRooms.Leave.alertBody(
                    roomToLeave?.summary.displayname
                        ?? roomToLeave?.summary.roomId
                        ?? "")),
                primaryButton: .destructive(
                    Text(L10n.Room.Remove.action),
                    action: {
                        self.leaveRoom()
                }),
            secondaryButton: .cancel())
        }
    }

    func setLeaveIndex(at offsets: IndexSet) {
        self.showConfirm = true
        for offset in offsets {
            self.leaveId = offset
        }
    }

    func leaveRoom() {
        guard let leaveId = self.leaveId, rooms.count > leaveId else { return }
        guard let mxRoom = self.roomToLeave?.room else { return }
        mxRoom.mxSession?.leaveRoom(mxRoom.roomId) { _ in }
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
