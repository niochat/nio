//
//  RecentRoomsContainerView.swift
//  RecentRoomsContainerView
//
//  Created by Finn Behrens on 06.08.21.
//  Copyright © 2021 Kilian Koeltzsch. All rights reserved.
//

import SwiftUI
import MatrixSDK

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


enum SelectedNavigationItem: Int, Identifiable {
    case settings
    case newConversation

    var id: Int {
        return self.rawValue
    }
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


struct RecentRoomsContainerView_Previews: PreviewProvider {
    static var previews: some View {
        RecentRoomsContainerView()
    }
}
