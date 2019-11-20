import SwiftUI

struct ConversationListView: View {
    @State private var selectedNavigationItem: SelectedNavigationItem?

    var settingsButton: some View {
        Button(action: {
            self.selectedNavigationItem = .settings
        }, label: {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 20))
        })
    }

    var newConversationButton: some View {
        Button(action: {
            self.selectedNavigationItem = .newMessage
        }, label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 20))
        })
    }

    var body: some View {
        NavigationView {
            List(0..<15, id: \.self) { conversation in
                NavigationLink(destination: ConversationView()) {
                    VStack {
                        HStack {
                            Text("Random conversation #\(conversation)")
                                .font(.headline)
                            Image(systemName: "lock.slash.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Spacer()
                            Text("\(conversation+10) minutes ago")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Text("""
                         Consequatur odit doloribus autem est aut dolor. Sunt expedita esse dolorem aut et est. \
                         Hic voluptate modi dignissimos delectus veritatis exercitationem quo. \
                         Voluptatem odit est rerum in. Nostrum animi dolores ad assumenda quibusdam voluptatum.
                         """)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(2)
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
