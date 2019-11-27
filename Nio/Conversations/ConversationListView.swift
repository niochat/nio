import SwiftUI
import SwiftMatrixSDK

struct ConversationListContainerView: View {
    @EnvironmentObject var store: MatrixStore<AppState, AppAction>
    @ObservedObject var recentRoomStore = NIORecentRooms()

    @State private var selectedNavigationItem: SelectedNavigationItem?

    var body: some View {
        ConversationListView(selectedNavigationItem: $selectedNavigationItem,
                             rooms: recentRoomStore.rooms)
            .sheet(item: $selectedNavigationItem, content: { NavigationSheet(selectedItem: $0) })
            .onAppear {
                self.recentRoomStore.startListening()
            }
    }
}

struct ConversationListView: View {
    @Binding fileprivate var selectedNavigationItem: SelectedNavigationItem?

    var rooms: [NIORoom]

    var settingsButton: some View {
        Button(action: {
            self.selectedNavigationItem = .settings
        }, label: {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 25))
        })
    }

    var newConversationButton: some View {
        Button(action: {
            self.selectedNavigationItem = .newMessage
        }, label: {
            Image(systemName: "plus")
                .font(.system(size: 25))
        })
    }

    var body: some View {
        NavigationView {
            List(rooms) { room in
                NavigationLink(destination: ConversationContainerView(room: room)) {
                    ConversationListCellContainerView(room: room)
                }
            }
            .navigationBarTitle("Nio", displayMode: .inline)
            .navigationBarItems(leading: settingsButton, trailing: newConversationButton)
        }
    }
}

private enum SelectedNavigationItem: Int, Identifiable {
    case settings
    case newMessage

    var id: Int {
        return self.rawValue
    }
}

private struct NavigationSheet: View {
    var selectedItem: SelectedNavigationItem

    var body: some View {
        switch selectedItem {
        case .settings:
            return Text("Settings")
        case .newMessage:
            return Text("New Message")
        }
    }
}

struct ConversationListView_Previews: PreviewProvider {
    static var previews: some View {
        ConversationListView(selectedNavigationItem: .constant(nil), rooms: [])
    }
}
