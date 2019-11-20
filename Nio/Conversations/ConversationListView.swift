import SwiftUI

struct ConversationListView: View {
    @State private var selectedNavigationItem: SelectedNavigationItem?

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

    var conversationView: ConversationView {
        ConversationView()
    }

    var body: some View {
        NavigationView {
            List(0..<15, id: \.self) { conversation in
                NavigationLink(destination: self.conversationView) {
                    HStack {
                        Image("stub-morpheus")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 50)
                            .mask(Circle())
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Morpheus #\(conversation)")
                                    .font(.headline)
                                Image(systemName: "lock.slash.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                Spacer()
                                Text("\(conversation+10) minutes ago")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Text(self.conversationView.messageStore.messages.randomElement()!.message)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .lineLimit(2)
                        }
                    }
                }
            }
            .navigationBarTitle("Nio", displayMode: .inline)
            .navigationBarItems(leading: settingsButton, trailing: newConversationButton)
        }
        .sheet(item: $selectedNavigationItem, content: { NavigationSheet(selectedItem: $0) })
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
        ConversationListView()
    }
}
