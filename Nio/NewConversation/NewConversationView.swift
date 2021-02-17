import SwiftUI
import MatrixSDK

import NioKit

struct NewConversationContainerView: View {
    @EnvironmentObject var store: AccountStore
    @Binding var createdRoomId: ObjectIdentifier?

    var body: some View {
        NewConversationView(store: store, createdRoomId: $createdRoomId)
    }
}

struct NewConversationView: View {
    @Environment(\.presentationMode) var presentationMode

    var store: AccountStore?

    @State private var users = [""]
    @State private var roomName = ""
    @State private var isPublic = false

    @State private var isWaiting = false
    @Binding var createdRoomId: ObjectIdentifier?
    @State private var errorMessage: String?

    var usersHeader: some View {
        EditButton().frame(maxWidth: .infinity, alignment: .trailing)
    }

    var usersFooter: some View {
        Text("\(L10n.NewConversation.forExample) \(store?.session?.myUserId ?? "@username:server.org")")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: usersHeader, footer: usersFooter) {
                    ForEach(0..<users.count, id: \.self) { index in
                        HStack {
                            TextField(L10n.NewConversation.usernamePlaceholder,
                                      text: Binding(get: { users[index] }, set: { users[index] = $0 }))
                                            // proxy binding prevents an index out of range crash on delete
                                .disableAutocorrection(true)
                                .autocapitalization(.none)
                            Spacer()
                            Button(action: addUser) {
                                Image(systemName: "plus.circle")
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .disabled(users.contains(""))
                            .opacity(index == users.count - 1 ? 1.0 : 0.0)
                        }
                    }
                    .onDelete { users.remove(atOffsets: $0) }
                    .deleteDisabled(users.count == 1)
                }

                if users.count > 1 {
                    Section {
                        TextField(L10n.NewConversation.roomName, text: $roomName)
                        Toggle(L10n.NewConversation.publicRoom, isOn: $isPublic)
                    }
                }

                Section {
                    HStack {
                        Button(action: createRoom) {
                            Text(L10n.NewConversation.createRoom)
                        }
                        .disabled(users.contains("") || (roomName.isEmpty && users.count > 1))

                        Spacer()
                        ProgressView()
                            .opacity(isWaiting ? 1.0 : 0.0)
                    }
                }
                .alert(item: $errorMessage) { errorMessage in
                    Alert(title: Text(L10n.NewConversation.alertFailed),
                          message: Text(errorMessage))
                }
            }
            .disabled(isWaiting)
            .navigationTitle(users.count > 1 ? L10n.NewConversation.titleRoom : L10n.NewConversation.titleChat)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.NewConversation.cancel) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    func addUser() {
        withAnimation {
            users.append("")
        }
    }

    func createRoom() {
        isWaiting = true

        let parameters = MXRoomCreationParameters()
        if users.count == 1 {
            parameters.inviteArray = users
            parameters.isDirect = true
            parameters.visibility = MXRoomDirectoryVisibility.private.identifier
            parameters.preset = MXRoomPreset.trustedPrivateChat.identifier
        } else {
            parameters.inviteArray = users
            parameters.isDirect = false
            parameters.name = roomName
            if isPublic {
                parameters.visibility = MXRoomDirectoryVisibility.public.identifier
                parameters.preset = MXRoomPreset.publicChat.identifier
            } else {
                parameters.visibility = MXRoomDirectoryVisibility.private.identifier
                parameters.preset = MXRoomPreset.privateChat.identifier
            }
        }

        store?.session?.createRoom(parameters: parameters) { response in
            switch response {
            case .success(let room):
                createdRoomId = room.id
                presentationMode.wrappedValue.dismiss()
            case.failure(let error):
                errorMessage = error.localizedDescription
                isWaiting = false
                print("Error on creating room: \(error)")
            }
        }
    }
}

struct NewConversationView_Previews: PreviewProvider {
    static var previews: some View {
        NewConversationView(store: nil, createdRoomId: .constant(nil))
            .preferredColorScheme(.light)
    }
}
