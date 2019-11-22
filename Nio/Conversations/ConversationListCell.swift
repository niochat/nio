import SwiftUI
import SwiftMatrixSDK

struct ConversationListCell: View {
    var conversation: MXRoom

    var image: some View {
        ZStack {
            Circle()
                .foregroundColor(.random)
            Text((conversation.summary.displayname ?? "").prefix(2).uppercased())
                .font(.title)
                .foregroundColor(.random)
        }
        .frame(width: 50, height: 50)

    }

    var body: some View {
        HStack {
            image

            VStack(alignment: .leading) {
                HStack {
                    Text(conversation.summary.displayname ?? "n/a")
                        .font(.headline)
                        .lineLimit(2)
                    if !conversation.summary.isEncrypted {
                        Image(systemName: "lock.slash.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    Spacer()
                    Text(Formatter.string(forRelativeDate: conversation.summary.lastMessageDate))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Text(conversation.summary.lastMessageString ?? "")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
        }
    }
}

struct ConversationListCell_Previews: PreviewProvider {
    static var previews: some View {
        ConversationListCell(conversation: MXRoom())
            .previewLayout(.sizeThatFits)
    }
}
