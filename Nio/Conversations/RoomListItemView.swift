import SwiftUI
import SwiftMatrixSDK

struct RoomListItemContainerView: View {
    var room: NIORoom

    var body: some View {
        let lastMessage = room.lastMessage
        let lastActivity = Formatter.string(forRelativeDate: room.summary.lastMessageDate)

        var accessibilityLabel = ""
        if room.isDirect {
            accessibilityLabel = "DM with \(room.summary.displayname ?? ""), \(lastActivity) \(room.lastMessage)"
        } else {
            accessibilityLabel = "Room \(room.summary.displayname ?? ""), \(lastActivity) \(room.lastMessage)"
        }

        return RoomListItemView(title: room.summary.displayname ?? "",
                                subtitle: lastMessage,
                                rightDetail: lastActivity,
                                badge: room.summary.localUnreadEventCount)
        .accessibility(label: Text(accessibilityLabel))
    }
}

struct RoomListItemView: View {
    var title: String
    var subtitle: String
    var rightDetail: String
    var badge: UInt

    var gradient: LinearGradient {
        let color: Color = .white
        let colors = [color.opacity(0.3), color.opacity(0.0)]
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var imageView: some View {
        Text(title.prefix(2).uppercased())
            .multilineTextAlignment(.center)
            .font(.system(.headline, design: .rounded))
            .lineLimit(1)
            .allowsTightening(true)
            .padding(10 * sizeCategory.scalingFactor)
            .aspectRatio(1.0, contentMode: .fill)
            .foregroundColor(.white)
            .background(
                Circle()
                    .foregroundColor(.accentColor)
                    .overlay(Circle().fill(self.gradient))
            )
            .accessibility(addTraits: .isImage)
    }

    var topView: some View {
        HStack(alignment: .top) {
            titleView
            Spacer()
            timeAgoView
        }
            .padding(.bottom, 5)
    }

    var titleView: some View {
        Text(title)
            .font(.headline)
            .lineLimit(2)
            .allowsTightening(true)
    }

    var timeAgoView: some View {
        Text(rightDetail)
            .font(.caption)
            .lineLimit(1)
            .allowsTightening(true)
            .foregroundColor(.secondary)
    }

    var bottomView: some View {
        HStack {
            subtitleView
            if badge != 0 {
                Spacer()
                badgeView
            }
        }
    }

    var subtitleView: some View {
        Text(subtitle)
            .multilineTextAlignment(.leading)
            .font(.subheadline)
            .lineLimit(2)
            .allowsTightening(true)
            .foregroundColor(.secondary)
    }

    var badgeView: some View {
        Text(String(self.badge))
            .font(.caption)
            .lineLimit(1)
            .allowsTightening(true)
            .foregroundColor(.white)
            // Make sure we get enough "breathing air" around the number:
            .padding(.vertical, 3 * sizeCategory.scalingFactor)
            .padding(.horizontal, 6 * sizeCategory.scalingFactor)
            .accessibility(label: Text("\(self.badge) new messages"))
            .background(
                GeometryReader { geometry in
                    Capsule()
                        .foregroundColor(.accentColor)
                        .overlay(Capsule().fill(self.gradient))
                        // Make sure the capsule always remains wider than its tall:
                        .frame(minWidth: geometry.size.height)
                }
            )
    }

    @Environment(\.sizeCategory) var sizeCategory

    var body: some View {
        HStack(alignment: .center) {
            imageView

            VStack(alignment: .leading, spacing: 0) {
                topView
                bottomView
            }
        }
        .padding([.vertical], 5 * sizeCategory.scalingFactor)
    }
}

//swiftlint:disable line_length
struct RoomListItemView_Previews: PreviewProvider {
    static func unreadCount() -> UInt {
        guard Bool.random() else {
            return 0
        }
        // Random number between 10^0.0 and 10^4.0:
        return UInt(pow(10.0, Double.random(in: 0.0..<4.0)))
    }

    static var list: some View {
        List {
            ForEach(ContentSizeCategory.allCases, id: \.self) { contentSizeCategory in
                RoomListItemView(
                    title: "Morpheus",
                    subtitle: "Red or blue 💊?",
                    rightDetail: "10m ago",
                    badge: unreadCount()
                )
                .environment(\.sizeCategory, contentSizeCategory)
            }
        }
    }

    static var previews: some View {
        Group {
            list
                .environment(\.colorScheme, .light)
            list
                .environment(\.colorScheme, .dark)
        }
        .accentColor(.purple)
    }
}
