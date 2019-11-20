import SwiftUI

struct ConversationListView: View {
    @State var showingNewConversationSheet = false

    var newConversationButton: some View {
        Button(action: {
            self.showingNewConversationSheet.toggle()
        }, label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 20))
        })
    }

    var body: some View {
        NavigationView {
            List(0..<10, id: \.self) { conversation in
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
            .navigationBarTitle("Conversations")
            .navigationBarItems(trailing: newConversationButton)
        }
        .sheet(isPresented: $showingNewConversationSheet) {
            Text("New conversation")
        }
    }
}

struct ConversationListView_Previews: PreviewProvider {
    static var previews: some View {
        ConversationListView()
    }
}
