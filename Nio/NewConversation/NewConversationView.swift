import SwiftUI
import MatrixSDK

import NioKit

struct NewConversationContainerView: View {
    @EnvironmentObject private var store: AccountStore
    @Binding var createdRoomId: ObjectIdentifier?

    var body: some View {
        NewConversationView(store: store, createdRoomId: $createdRoomId)
    }
}

private struct NewConversationView: View {
    @Environment(\.presentationMode) private var presentationMode

    let store: AccountStore?

    @State private var users = [""]
  #if !os(macOS)
    @State private var editMode = EditMode.inactive
  #endif
    @State private var roomName = ""
    @State private var isPublic = false

    @State private var isWaiting = false
    @Binding var createdRoomId: ObjectIdentifier?
    @State private var errorMessage: String?

    @MainActor
    private var usersFooter: some View {
        Text("\(L10n.NewConversation.forExample) \(store?.session?.myUserId ?? "@username:server.org")")
    }

    @MainActor
    private var form: some View {
        Form {
            Section(footer: usersFooter) {
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
                  #if !os(macOS)
                    Button(action: {
                        Task.init(priority: .userInitiated) {
                            createRoom
                        }
                        }) {
                        Text(verbatim: L10n.NewConversation.createRoom)
                    }
                    .disabled(users.contains("") || (roomName.isEmpty && users.count > 1))
                  #endif
                    Spacer()
                    ProgressView()
                        .opacity(isWaiting ? 1.0 : 0.0)
                }
            }
            .alert(item: $errorMessage) { errorMessage in
                Alert(title: Text(verbatim: L10n.NewConversation.alertFailed),
                      message: Text(errorMessage))
            }
        }
    }

    var body: some View {
      #if os(macOS)
        form
          // TBD: no edit-mode
          .disabled(isWaiting)
          .toolbar {
              ToolbarItem(placement: .cancellationAction) {
                  Button(L10n.NewConversation.cancel) {
                      presentationMode.wrappedValue.dismiss()
                  }
              }
              ToolbarItem(placement: .confirmationAction) {
                  Button(action: createRoom) {
                      Text(verbatim: L10n.NewConversation.createRoom)
                  }
                  .disabled(users.contains("") || (roomName.isEmpty && users.count > 1))
              }
          }
          .padding()
      #else
        NavigationView {
          form
            .environment(\.editMode, $editMode)
            .onChange(of: users.count) { count in
                editMode = count > 1 ? editMode : .inactive
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
                ToolbarItem(placement: .automatic) {
                    if users.count > 1 {
                        // It seems that `.environment(\.editMode, $editMode)`
                        // and `EditButton` cannot coexist.
                        Button(editMode.isEditing
                                ? L10n.NewConversation.done
                                : L10n.NewConversation.edit
                        ) {
                            editMode = editMode.isEditing ? .inactive : .active
                        }
                    }
                }
            }
        }
      #endif
    }

    private func addUser() {
        withAnimation {
            users.append("")
        }
    }

    @MainActor
    private func createRoom() {
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
            @unknown default:
                fatalError("Unexpected Matrix response: \(response)")
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
