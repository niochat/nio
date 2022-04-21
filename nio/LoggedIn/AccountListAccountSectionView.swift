//
//  AccountListAccountSectionView.swift
//  Nio
//
//  Created by Finn Behrens on 21.04.22.
//

import SwiftUI
import MatrixClient
import NioKit

struct AccountListAccountSectionView: View {
    @EnvironmentObject var account: NioAccount
    @Binding var searchText: String


    @State var showMuteAlert: Bool = false

    @Environment(\.editMode) private var editMode

    var spaces = ["Space 1"]

    var body: some View {
        Section(account.info.name) {
            NavigationLink {
                Text("foo")
            } label: {
                Label("Home", systemImage: "house")
            }

            ForEach(spaces, id: \.self) { space in
                NavigationLink {
                    Text(space)
                } label: {
                    Label(space, systemImage: "house.fill")

                }
                .tag(space)
                .disabled(editMode?.wrappedValue != EditMode.inactive)
                .swipeActions(allowsFullSwipe: true) {

                    Button {
                        print("muting")
                        showMuteAlert = true
                    } label: {
                        Label("Mute", systemImage: "bell.slash.fill")
                    }
                    .tint(.indigo)

                    Button {
                        print("edit")
                    } label: {
                        Label("Edit", systemImage: "ellipsis")
                    }
                }
            }
        }
        .confirmationDialog("Mute", isPresented: $showMuteAlert) {
            Button {
                print("all")
            } label: {
                Text("all")
            }

            Button {
                print("rooms")
            } label: {
                Text("rooms")
            }
        }
    }
}

struct AccountListAccountSectionView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            AccountListAccountSectionView(searchText: .constant("")).environmentObject( NioAccountStore.generatePreviewAccount(NioAccountStore.preview, name: "Bob"))
        }
        .listStyle(.sidebar)
    }
}
