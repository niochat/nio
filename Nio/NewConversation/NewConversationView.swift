import SwiftUI
import MatrixSDK

import NioKit

enum UserStatus {
    case unknown         // Validity of user is still unknown.
    case notValid       // User is not valid.
    case valid          // User is valid.
    case retrieving     // Validity of user is being retrieved from identity server.
}

struct NewConversationContainerView: View {
    @EnvironmentObject private var store: AccountStore
    @Binding var createdRoomId: ObjectIdentifier?
    @AppStorage("matrixUsers") private var matrixUsersJSON: String = ""

    var body: some View {
        NewConversationView(
            store: store,
            createdRoomId: $createdRoomId,
            matrixUsers: { () -> [MatrixUser] in
                do {
                    var matrixArray: [MatrixUser] = try JSONDecoder().decode(
                        [MatrixUser].self, from: matrixUsersJSON.data(using: .utf8) ?? Data()
                    )
                    matrixArray.sort(by: { (lhs, rhs) in return lhs.getFirstName() > rhs.getFirstName() })
                    return matrixArray
                } catch {
                    return []
                }
            }()
        )
    }
}

private struct NewConversationView: View {
    @Environment(\.presentationMode) private var presentationMode
    @AppStorage("identityServerBool") private var identityServerBool: Bool = false

    let store: AccountStore?

    @State private var users = [""]
    @State private var usersVerified: [UserStatus] = [UserStatus.unknown]

    @State private var numCalls: Int = 0

    @State private var isRetrieving = false

  #if !os(macOS)
    @State private var editMode = EditMode.inactive
  #endif
    @State private var roomName = ""
    @State private var isPublic = false

    @State private var isWaiting = false
    @Binding var createdRoomId: ObjectIdentifier?
    @State private var errorMessage: String?

    let matrixUsers: [MatrixUser]

    private var usersFooter: some View {
        Text("\(L10n.NewConversation.forExample) \(store?.session?.myUserId ?? "@username:server.org")")
    }

    private var form: some View {
        Form {
            Section(footer: usersFooter) {
                ForEach(0..<users.count, id: \.self) { index in
                    HStack {
                        if usersVerified[index] == UserStatus.unknown {
                            Image(systemName: "questionmark.circle")
                        } else if usersVerified[index] == UserStatus.valid {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(Color.green)
                        } else if usersVerified[index] == UserStatus.notValid {
                            Image(systemName: "multiply.circle")
                                .foregroundColor(Color.red)
                        } else if usersVerified[index] == UserStatus.retrieving {
                            Image(systemName: "arrow.2.circlepath.circle")
                                .rotationEffect(Angle.degrees(isRetrieving ? 360 : 0))
                                .animation(Animation.linear.repeatForever(autoreverses: false).speed(0.25))
                                .onAppear {
                                    self.isRetrieving.toggle()
                                }
                                .onDisappear {
                                    self.isRetrieving.toggle()
                                }
                        }
                        // proxy binding prevents an index out of range crash on delete
                        TextField(
                            (
                                identityServerBool ?
                                    L10n.NewConversation.usernamePlaceholderExtended :
                                    L10n.NewConversation.usernamePlaceholder
                            ),
                            text: Binding(get: { users[index] }, set: { users[index] = $0; findUser(userIndex: index) })
                        )
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
                    Button(action: createRoom) {
                        Text(verbatim: L10n.NewConversation.createRoom)
                    }
                    .disabled(
                        users.contains("")
                            || (roomName.isEmpty && users.count > 1)
                            || usersVerified.contains(UserStatus.notValid)
                            || usersVerified.contains(UserStatus.retrieving)
                            || usersVerified.contains(UserStatus.unknown)
                    )
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

            Section(header: Text(L10n.NewConversation.contactsMatrix)) {
                ForEach(0..<matrixUsers.count, id: \.self) { index in
                    HStack {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(matrixUsers[index].getFirstName() + " " + matrixUsers[index].getLastName())

                                Text(matrixUsers[index].getMatrixID())
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(
                                action: {
                                    var emptyIndex = -1
                                    if users.contains("") {
                                        emptyIndex = users.firstIndex(where: {$0 == ""}) ?? users.count - 1
                                        users[emptyIndex] = matrixUsers[index].getMatrixID()
                                    } else {
                                        addUser()
                                        emptyIndex = users.count - 1
                                        users[emptyIndex] = matrixUsers[index].getMatrixID()
                                    }
                                    findUser(userIndex: emptyIndex)
                                },
                                label: {
                                    Image(systemName: "plus.circle")
                                }
                            )
                            .disabled(
                                users.contains(matrixUsers[index].getMatrixID())
                            )

                        }
                    }
                }
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
            usersVerified.append(UserStatus.unknown)
            users.append("")
        }
    }

    private func findUser(userIndex: Int, recheck: Bool = false) {
        usersVerified[userIndex] = UserStatus.retrieving
        let user = users[userIndex]
        // Match for Matrix ID pattern.
        let pattern = "@[A-Z0-9a-z._%+-]+:[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let result = user.range(of: pattern, options: .regularExpression)

        // Check if user is not a Matrix ID, Identity Server is turned on does not start with an @ character
        // (indicating a Matrix ID is coming), and check if user is long enough to be an email/ phone number
        // to reduce the number of calls.
        if result == nil && identityServerBool && !user.starts(with: "@") && user.count >= 6 {
            numCalls += 1
            let mx3pids: [MX3PID] = [
                // Look for email occurrences on the identity server.
                MX3PID.init(medium: MX3PID.Medium.email, address: user),
                // Look for phone number occurrences on the identity server.
                MX3PID.init(
                    medium: MX3PID.Medium.msisdn,
                    address: user.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: " ", with: "")
                ),
            ]
            store?.identityService?.lookup3PIDs(mx3pids) { response in
                numCalls -= 1
                // Check if it is the last identity request.
                if numCalls == 0 {
                    if response.value?.count ?? 0 > 0 {
                        response.value?.forEach({ (responseItem: (key: MX3PID, value: String)) in
                            users[userIndex] = responseItem.value
                            usersVerified[userIndex] = UserStatus.valid
                        })
                    } else {
                        // In case the request did not come back in the correct order send the last value again.
                        if !recheck {
                            findUser(userIndex: userIndex, recheck: true)
                        } else {
                            usersVerified[userIndex] = UserStatus.notValid
                        }
                    }
                }
            }
        } else if result != nil {
            usersVerified[userIndex] = UserStatus.valid
        } else {
            usersVerified[userIndex] = UserStatus.notValid
        }
    }

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
        NewConversationView(store: nil, createdRoomId: .constant(nil), matrixUsers: [])
            .preferredColorScheme(.light)
    }
}
