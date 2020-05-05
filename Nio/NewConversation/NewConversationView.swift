import SwiftUI
import SwiftMatrixSDK

struct NewConversationContainerView: View {
    @EnvironmentObject var store: AccountStore
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        NewConversationView(store: store)
    }
}

struct NewConversationView: View {
    @Environment(\.presentationMode) var presentationMode

    var store: AccountStore?
    var parameters: MXRoomCreationParameters = MXRoomCreationParameters.init()
    var visibility: MXRoomDirectoryVisibility = MXRoomDirectoryVisibility.private
    @State var user: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Matrix ID", text: $user)
                }
                Section {
                    Button(action: {
                        if self.user != "" {
                            self.parameters.inviteArray = [self.user]
                        }
                        self.parameters.isDirect = true
                        self.store!.session?.createRoom(parameters: self.parameters) { _ in
                            self.presentationMode.wrappedValue.dismiss()
                        }
                    }, label: {
                        Text("Start Chat")
                    })
                }

            }
            .navigationBarTitle(Text(L10n.NewConversation.title), displayMode: .inline)
        }
    }
}

struct NewConversationView_Previews: PreviewProvider {
    static var previews: some View {
        NewConversationView(store: nil)
    }
}
