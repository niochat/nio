import SwiftUI
import SwiftMatrixSDK

struct ConversationListCellContainerView: View {

    var conversation: MXRoom

    var body: some View {
        ConversationListCell(title: conversation.summary.displayname ?? "",
                             subtitle: conversation.summary.lastMessageString ?? "",
                             rightDetail: Formatter.string(forRelativeDate: conversation.summary.lastMessageDate),
                             badge: conversation.summary.localUnreadEventCount)
    }
}

struct ConversationListCell: View {
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
        HStack {
            image

            VStack(alignment: .leading) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .lineLimit(2)
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
struct ConversationListCell_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ConversationListCell(title: "Morpheus",
                                 subtitle: "Red or blue 💊?",
                                 rightDetail: "10 minutes ago",
                                 badge: 2)
                .padding()
            ConversationListCell(title: "Morpheus",
                                 subtitle: "Nesciunt quaerat voluptatem enim sunt. Provident id consequatur tempora nostrum. Sit in voluptatem consequuntur at et provident est facilis. Ut sit ad sit quam commodi qui.",
                                 rightDetail: "12:29",
                                 badge: 0)
            .padding()
        }
        .accentColor(.purple)
        .previewLayout(.sizeThatFits)
    }
}
