//
//  RecentRoomsView.swift
//  Nio
//
//  Created by Finn Behrens on 13.06.21.
//  Copyright © 2021 Kilian Koeltzsch. All rights reserved.
//

import SwiftUI
import MatrixSDK

import NioKit

struct RecentRoomsView: View {
    @EnvironmentObject var store: AccountStore

    @Binding var selectedNavigationItem: SelectedNavigationItem?
    @Binding var selectedRoomId: MXRoom.MXRoomId?
    @Binding var searchText: String

    let rooms: [NIORoom]

    private var joinedRooms: [NIORoom] {
        rooms.filter {
            $0.room.summary.membership == .join &&
            (searchText.isEmpty ? true : $0.displayName.lowercased().contains(searchText.lowercased()))
        }
    }

    private var invitedRooms: [NIORoom] {
        rooms.filter {
            $0.room.summary.membership == .invite &&
            (searchText.isEmpty ? true : $0.displayName.lowercased().contains(searchText.lowercased()))
        }
    }

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
}



struct RecentRoomsView_Previews: PreviewProvider {
    static var previews: some View {
        RecentRoomsView(selectedNavigationItem: .constant(nil), selectedRoomId: .constant(nil), searchText: .constant(""), rooms: [])
    }
}
