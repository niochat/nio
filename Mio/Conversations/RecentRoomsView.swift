//
//  RecentRoomsView.swift
//  Mio
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
    @Binding var selectedRoomId: ObjectIdentifier?

    let rooms: [NIORoom]

    private var joinedRooms: [NIORoom] {
        rooms.filter {$0.room.summary.membership == .join}
    }

    private var invitedRooms: [NIORoom] {
        rooms.filter {$0.room.summary.membership == .invite}
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
            .listStyle(SidebarListStyle())
            .navigationTitle("Mio")
            .frame(minWidth: Style.minSidebarWidth)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { self.selectedNavigationItem = .newConversation }) {
                        Label(L10n.RecentRooms.AccessibilityLabel.newConversation,
                              systemImage: SFSymbol.newConversation.rawValue)
                    }
                }
            }
        }
    }
}

struct RecentRoomsView_Previews: PreviewProvider {
    static var previews: some View {
        RecentRoomsView(selectedNavigationItem: .constant(nil), selectedRoomId: .constant(nil), rooms: [])
    }
}
