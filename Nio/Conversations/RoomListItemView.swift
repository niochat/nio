import SwiftUI
import SwiftMatrixSDK

struct RoomListItemContainerView: View {
    var room: NIORoom

    var body: some View {
        let lastMessage = room.lastMessage
        let lastActivity = Formatter.string(forRelativeDate: room.summary.lastMessageDate)
        return RoomListItemView(title: room.summary.displayname ?? "",
                                    subtitle: lastMessage,
                                    rightDetail: lastActivity,
                                    badge: room.summary.localUnreadEventCount)
    }
}

struct RoomListItemView: View {
    var title: String
    var subtitle: String
    var rightDetail: String
    var badge: UInt

    var image: some View {
        ZStack {
            Circle()
                .foregroundColor(.random)
            Text(title.prefix(2).uppercased())
                .font(.headline)
                .foregroundColor(.random)
        }
        .frame(width: 40, height: 40)

    }

    var body: some View {
        HStack(alignment: .center) {
            image

            VStack(alignment: .leading) {
                HStack(alignment: .top) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(2)
                        .padding(.bottom, 5)
                        .allowsTightening(true)
                    Spacer()
                    Text(rightDetail)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                HStack {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .allowsTightening(true)
                    if badge != 0 {
                        Spacer()
                        ZStack {
                            Circle()
                                .foregroundColor(.accentColor)
                                .frame(width: 20, height: 20)
                            Text(String(badge))
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
    }
}

//swiftlint:disable line_length
struct RoomListItemView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RoomListItemView(title: "Morpheus",
                                 subtitle: "Red or blue 💊?",
                                 rightDetail: "10 minutes ago",
                                 badge: 2)
            RoomListItemView(title: "Morpheus",
                                 subtitle: "Red or blue 💊?",
                                 rightDetail: "10 minutes ago",
                                 badge: 0)
            RoomListItemView(title: "Morpheus",
                                 subtitle: "Nesciunt quaerat voluptatem enim sunt. Provident id consequatur tempora nostrum. Sit in voluptatem consequuntur at et provident est facilis. Ut sit ad sit quam commodi qui.",
                                 rightDetail: "12:29",
                                 badge: 0)
            RoomListItemView(title: "Morpheus",
                                 subtitle: "Nesciunt quaerat voluptatem enim sunt. Provident id consequatur tempora nostrum. Sit in voluptatem consequuntur at et provident est facilis. Ut sit ad sit quam commodi qui.",
                                 rightDetail: "12:29",
                                 badge: 1)
        }
//        .padding()
        .accentColor(.purple)
        .previewLayout(.sizeThatFits)
    }
}
