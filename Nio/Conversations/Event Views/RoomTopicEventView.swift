import SwiftUI

struct RoomTopicEventView: View {
    let sender: String
    let topic: String

    var body: some View {
        HStack {
            Spacer()
            Text("\(sender) changed the topic to \(topic)")
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
        }
        .padding(.vertical, 3)
    }
}

struct RoomTopicEventView_Previews: PreviewProvider {
    static var previews: some View {
        RoomTopicEventView(sender: "Jane", topic: "xoxo gossip girl")
    }
}
