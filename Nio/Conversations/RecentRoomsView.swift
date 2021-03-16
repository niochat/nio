import SwiftUI
import MatrixSDK
import Introspect

import NioKit

struct RecentRoomsContainerView: View {
    @EnvironmentObject var store: AccountStore
    @AppStorage("accentColor") var accentColor: Color = .purple

    @State private var selectedNavigationItem: SelectedNavigationItem?
    @State private var selectedRoomId: ObjectIdentifier?

    private func autoselectFirstRoom() {
      if selectedRoomId == nil {
          selectedRoomId = store.rooms.first?.id
      }
    }

    var body: some View {
        RecentRoomsView(selectedNavigationItem: $selectedNavigationItem,
                        selectedRoomId: $selectedRoomId,
                        rooms: store.rooms)
            .sheet(item: $selectedNavigationItem) {
                NavigationSheet(selectedItem: $0, selectedRoomId: $selectedRoomId)
                    // This really shouldn't be necessary. SwiftUI bug?
                    // 2021-03-07(hh): SwiftUI doesn't document when
                    //                 environments are preserved. Also
                    //                 different between platforms.
                    .environmentObject(self.store)
                    .accentColor(accentColor)
            }
            .onAppear {
                self.store.startListeningForRoomEvents()
                if #available(macOS 11, *) { autoselectFirstRoom() }
            }
    }
}

struct RecentRoomsView: View {
    @EnvironmentObject var store: AccountStore

    @Binding fileprivate var selectedNavigationItem: SelectedNavigationItem?
    @Binding fileprivate var selectedRoomId: ObjectIdentifier?

    let rooms: [NIORoom]

    private var joinedRooms: [NIORoom] {
        rooms.filter {$0.room.summary.membership == .join}
    }

    private var invitedRooms: [NIORoom] {
        rooms.filter {$0.room.summary.membership == .invite}
    }

  #if os(macOS)
    var body: some View {
        NavigationView {
            List {
                if !invitedRooms.isEmpty {
                    RoomsListSection(
                        sectionHeader: L10n.RecentRooms.PendingInvitations.header,
                        rooms: invitedRooms,
                        onLeaveAlertTitle: L10n.RecentRooms.PendingInvitations.Leave.alertTitle,
                        selectedRoomId: $selectedRoomId
                    )
                }

                RoomsListSection(
                    sectionHeader: invitedRooms.isEmpty ? nil : L10n.RecentRooms.Rooms.header ,
                    rooms: joinedRooms,
                    onLeaveAlertTitle: L10n.RecentRooms.Leave.alertTitle,
                    selectedRoomId: $selectedRoomId
                )

            }
            .listStyle(SidebarListStyle())
            .navigationTitle("Mio")
            .frame(minWidth: Style.minSidebarWidth)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { self.selectedNavigationItem = .settings }) {
                        Label(L10n.RecentRooms.AccessibilityLabel.settings,
                              systemImage: SFSymbol.settings.rawValue)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { self.selectedNavigationItem = .newConversation }) {
                        Label(L10n.RecentRooms.AccessibilityLabel.newConversation,
                              systemImage: SFSymbol.newConversation.rawValue)
                    }
                }
            }
        }
    }
  #else // iOS
    private var settingsButton: some View {
        Button(action: {
            self.selectedNavigationItem = .settings
        }, label: {
            Image(Asset.Icon.user.name)
                .resizable()
                .frame(width: 30.0, height: 30.0)
                .accessibility(label: Text(verbatim: L10n.RecentRooms.AccessibilityLabel.settings))
        })
    }

    private var newConversationButton: some View {
        Button(action: {
            self.selectedNavigationItem = .newConversation
        }, label: {
            Image(Asset.Icon.addRoom.name)
                .resizable()
                .frame(width: 30.0, height: 30.0)
                .accessibility(label: Text(verbatim: L10n.RecentRooms.AccessibilityLabel.newConversation))
        })
    }

    var body: some View {
        NavigationView {
            List {
                if !invitedRooms.isEmpty {
                    RoomsListSection(
                        sectionHeader: L10n.RecentRooms.PendingInvitations.header,
                        rooms: invitedRooms,
                        onLeaveAlertTitle: L10n.RecentRooms.PendingInvitations.Leave.alertTitle,
                        selectedRoomId: $selectedRoomId
                    )
                }

                RoomsListSection(
                    sectionHeader: invitedRooms.isEmpty ? nil : L10n.RecentRooms.Rooms.header ,
                    rooms: joinedRooms,
                    onLeaveAlertTitle: L10n.RecentRooms.Leave.alertTitle,
                    selectedRoomId: $selectedRoomId
                )

            }
            .listStyle(GroupedListStyle())
            .introspectTableView { tableView in
                guard invitedRooms.isEmpty else { return }
                var frame = CGRect.zero
                frame.size.height = .leastNormalMagnitude
                tableView.tableHeaderView = UIView(frame: frame)
            }
            .navigationBarTitle("Nio", displayMode: .inline)
            .navigationBarItems(leading: settingsButton, trailing: newConversationButton)
        }
    }
  #endif // iOS
}

struct RoomsListSection: View {
    let sectionHeader: String?
    let rooms: [NIORoom]
    let onLeaveAlertTitle: String

    @Binding var selectedRoomId: ObjectIdentifier?

    @State private var showConfirm: Bool = false
    @State private var leaveId: Int?

    private var roomToLeave: NIORoom? {
        guard
            let leaveId = self.leaveId,
            rooms.count > leaveId
        else { return nil }
        return self.rooms[leaveId]
    }

    private var sectionContent: some View {
        ForEach(rooms) { room in
            NavigationLink(destination: RoomContainerView(room: room), tag: room.id, selection: $selectedRoomId) {
                RoomListItemContainerView(room: room)
            }
        }
        .onDelete(perform: setLeaveIndex)
    }

    @ViewBuilder
    private var section: some View {
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
                message: Text(verbatim: L10n.RecentRooms.Leave.alertBody(
                    roomToLeave?.summary.displayname
                        ?? roomToLeave?.summary.roomId
                        ?? "")),
                primaryButton: .destructive(
                    Text(verbatim: L10n.Room.Remove.action),
                    action: self.leaveRoom),
                secondaryButton: .cancel())
        }
    }

    private func setLeaveIndex(at offsets: IndexSet) {
        self.showConfirm = true
        for offset in offsets {
            self.leaveId = offset
        }
    }

    private func leaveRoom() {
        guard let leaveId = self.leaveId, rooms.count > leaveId else { return }
        guard let mxRoom = self.roomToLeave?.room else { return }
        mxRoom.mxSession?.leaveRoom(mxRoom.roomId) { _ in }
    }
}

private enum SelectedNavigationItem: Int, Identifiable {
    case settings
    case newConversation

    var id: Int {
        return self.rawValue
    }
}

private struct NavigationSheet: View {
    var selectedItem: SelectedNavigationItem
    @Binding var selectedRoomId: ObjectIdentifier?

    var body: some View {
        switch selectedItem {
        case .settings:
            SettingsContainerView()
        case .newConversation:
            NewConversationContainerView(createdRoomId: $selectedRoomId)
        }
    }
}

struct RecentRoomsView_Previews: PreviewProvider {
    static var previews: some View {
        RecentRoomsView(selectedNavigationItem: .constant(nil), selectedRoomId: .constant(nil), rooms: [])
    }
}
