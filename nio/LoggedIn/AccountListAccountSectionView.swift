//
//  AccountListAccountSectionView.swift
//  Nio
//
//  Created by Finn Behrens on 21.04.22.
//

import SwiftUI
import MatrixClient
import NioKit
import Combine

struct AccountListAccountSectionView: View {
    @EnvironmentObject var account: NioAccount
    @Binding var searchText: String


    @State var showMuteAlert: Bool = false

    @Environment(\.editMode) private var editMode
    @EnvironmentObject var deepLinker: DeepLinker

    var spaces = ["Space 1"]

    var body: some View {
        Section(account.info.name) {
            NavigationLink(tag: .home(account.mxID), selection: $deepLinker.mainSelection) {
                //Text("\(account.info.name) foo" )
                Button("Foo") {
                    deepLinker.mainSelection = .preferences
                    deepLinker.preferenceSelector = .account(account.mxID)
                }
            } label: {
                Label("Home", systemImage: "house")
            }

            ForEach(spaces, id: \.self) { space in
                NavigationLink(tag: .space(account.mxID, space), selection: $deepLinker.mainSelection, destination: { Text("\(account.info.name): space") }, label: { Label(space, systemImage: "house.fill")})
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
            //AccountListAccountSectionView(searchText: .constant("")).environmentObject( NioAccountStore.generatePreviewAccount(NioAccountStore.preview, name: "Bob"))
        }
        .listStyle(.sidebar)
    }
}
