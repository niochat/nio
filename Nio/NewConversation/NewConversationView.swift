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

    @State var isPublic = false
    @State private var users = [""]

    @State var isWaiting = false
    @Binding var createdRoomId: ObjectIdentifier?
    @State private var isPresentingAlert = false

    var body: some View {
        NavigationView {
            Form {
                Section(footer: Text("For example \(store?.session?.myUserId ?? "@username:server.org")")) {
                    ForEach(0..<users.count, id: \.self) { index in
                        HStack {
                            TextField("Matrix ID", text: $users[index])
                            Spacer()
                            Button(action: addUser) {
                                Image(systemName: "plus.circle")
                            }
                            .disabled(users.contains(""))
                            .opacity(index == users.count - 1 ? 1.0 : 0.0)
                        }
                    }
                    .onDelete { users.remove(atOffsets: $0) }
                    .deleteDisabled(users.count == 1)
                }

                if users.count > 1 {
                    Section {
                        Toggle("Public Room", isOn: $isPublic)
                    }
                }

                Section {
                    HStack {
                        Button(action: createRoom) {
                            Text("Start Chat")
                        }
                        .disabled(users.contains(""))

                        Spacer()
                        ProgressView()
                            .opacity(isWaiting ? 1.0 : 0.0)
                    }
                }
                .alert(isPresented: $isPresentingAlert) {
                    Alert(title: Text("Failed To Start Chat"))
                }
            }
            .disabled(isWaiting)
            .navigationTitle(users.count > 1 ? "New Room" : L10n.NewConversation.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
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
            if isPublic {
                parameters.visibility = MXRoomDirectoryVisibility.public.identifier
                parameters.preset = MXRoomPreset.publicChat.identifier
            } else {
                parameters.visibility = MXRoomDirectoryVisibility.private.identifier
                parameters.preset = MXRoomPreset.privateChat.identifier
            }
        }

        store!.session?.createRoom(parameters: parameters) { response in
            switch response {
            case .success(let room):
                createdRoomId = room.id
                presentationMode.wrappedValue.dismiss()
            case.failure(let error):
                isPresentingAlert = true
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
