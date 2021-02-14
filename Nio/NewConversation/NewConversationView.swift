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
    var parameters: MXRoomCreationParameters = MXRoomCreationParameters.init()
    var visibility: MXRoomDirectoryVisibility = MXRoomDirectoryVisibility.private
    @State private var user: String = ""

    @Binding var createdRoomId: ObjectIdentifier?
    @State private var isPresentingAlert = false

    var body: some View {
        NavigationView {
            Form {
                Section(footer: Text("For example \(store?.session?.myUserId ?? "@user:server.org")")) {
                    TextField("Matrix ID", text: $user)
                }
                Section {
                    Button(action: {
                        if self.user != "" {
                            self.parameters.inviteArray = [self.user]
                        }
                        self.parameters.isDirect = true
                        self.store!.session?.createRoom(parameters: self.parameters) { response in
                            switch response {
                            case .success(let room):
                                createdRoomId = room.id
                                presentationMode.wrappedValue.dismiss()
                            case.failure(let error):
                                isPresentingAlert = true
                                print("Error on creating room: \(error)")
                            }
                        }
                    }, label: {
                        Text("Start Chat")
                    })
                }
                .alert(isPresented: $isPresentingAlert) {
                    Alert(title: Text("Failed To Start Chat"))
                }
            }
            .navigationBarTitle(Text(L10n.NewConversation.title), displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct NewConversationView_Previews: PreviewProvider {
    static var previews: some View {
        NewConversationView(store: nil, createdRoomId: .constant(nil))
    }
}
