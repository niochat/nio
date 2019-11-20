import SwiftUI

struct ChatsListView: View {
    @State var showingNewChatSheet = false

    var newChatButton: some View {
        Button(action: {
            self.showingNewChatSheet.toggle()
        }, label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 20))
        })
    }

    var body: some View {
        NavigationView {
            List(0..<10, id: \.self) { chat in
                NavigationLink(destination: ChatView()) {
                    VStack {
                        HStack {
                            Text("Random chat #\(chat)")
                                .font(.headline)
                            Image(systemName: "lock.slash.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Spacer()
                            Text("\(chat+10) minutes ago")
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
            .navigationBarTitle("Chats")
            .navigationBarItems(trailing: newChatButton)
        }
        .sheet(isPresented: $showingNewChatSheet) {
            Text("New conversation")
        }
    }
}

struct ChatsListView_Previews: PreviewProvider {
    static var previews: some View {
        ChatsListView()
    }
}
