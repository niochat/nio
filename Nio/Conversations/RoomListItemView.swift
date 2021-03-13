import SwiftUI
import MatrixSDK
import SDWebImageSwiftUI

import NioKit

struct RoomListItemContainerView: View {
    @EnvironmentObject private var store: AccountStore

    let room: NIORoom

    private var roomAvatarURL: URL? {
        guard let client = store.client,
              let homeserver = URL(string: client.homeserver),
              let avatar = room.summary.avatar else { return nil }
        return MXURL(mxContentURI: avatar)?.contentURL(on: homeserver)
    }

    var body: some View {
        let roomName = room.summary.displayname ?? ""
        let lastMessage = room.lastMessage
        let lastActivity = Formatter.string(forRelativeDate: room.summary.lastMessageDate)

        let accessibilityLabel: String
        if room.isDirect {
            accessibilityLabel = L10n.RecentRooms.AccessibilityLabel.dm(roomName, lastActivity, lastMessage)
        } else {
            accessibilityLabel = L10n.RecentRooms.AccessibilityLabel.room(roomName, lastActivity, lastMessage)
        }

        return RoomListItemView(title: room.summary.displayname ?? "",
                                subtitle: lastMessage,
                                rightDetail: lastActivity,
                                badge: room.summary.localUnreadEventCount,
                                roomAvatarURL: roomAvatarURL)
               .accessibility(label: Text(verbatim: accessibilityLabel))
    }
}

struct RoomListItemView: View {
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast: ColorSchemeContrast

    fileprivate let title: String
    fileprivate let subtitle: String
    fileprivate let rightDetail: String
    fileprivate let badge: UInt
    fileprivate let roomAvatarURL: URL?

    private var gradient: LinearGradient {
        let color: Color = .white
        let colors = [color.opacity(0.3), color.opacity(0.0)]
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var prefixAvatar: some View {
        GeometryReader { geometry in
            Text(verbatim: title.prefix(2).uppercased())
                .multilineTextAlignment(.center)
                .font(.system(.headline, design: .rounded))
                .lineLimit(1)
                .allowsTightening(true)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .foregroundColor(.init(UXColor.textOnAccentColor(for: colorScheme)))
                .background(
                    Color.accentColor.overlay(gradient)
                )
        }
        .accessibility(addTraits: .isImage)
    }

    private var topView: some View {
        HStack(alignment: .top) {
            titleView
            Spacer()
            timeAgoView
        }
        .padding(.bottom, 5)
    }

    private var titleView: some View {
        Text(verbatim: title)
            .font(.headline)
            .lineLimit(1)
            .allowsTightening(true)
    }

    private var timeAgoView: some View {
        Text(verbatim: rightDetail)
            .font(.caption)
            .lineLimit(1)
            .allowsTightening(true)
            .foregroundColor(.secondary)
    }

    private var bottomView: some View {
        HStack {
            subtitleView
            if badge != 0 {
                Spacer()
                badgeView
            }
        }
    }

    private var subtitleView: some View {
        Text(verbatim: subtitle.isEmpty ? " " : subtitle)     // Replace empty string with space to maintain height
            .multilineTextAlignment(.leading)
            .font(.subheadline)
            .lineLimit(1)
            .allowsTightening(true)
            .foregroundColor(.secondary)
            // Maintain consistent vertical padding when there isn't a badge
            .padding(.vertical, badgeTextVerticalPadding)
    }

    private var badgeView: some View {
        Text(verbatim: String(self.badge))
            .font(.caption)
            .lineLimit(1)
            .allowsTightening(true)
            .foregroundColor(.init(UXColor.textOnAccentColor(for: colorScheme)))
            // Make sure we get enough "breathing air" around the number:
            .padding(.vertical, badgeTextVerticalPadding)
            .padding(.horizontal, 6 * sizeCategory.scalingFactor)
            .accessibility(label: Text(verbatim: L10n.RecentRooms.AccessibilityLabel.newMessageBadge(Int(self.badge))))
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

    private var badgeTextVerticalPadding: CGFloat { 3 * sizeCategory.scalingFactor }

    private var avatarView: some View {
        Circle()
            .foregroundColor(.clear)
            .aspectRatio(1, contentMode: .fill)
            .overlay(image.mask(Circle()))
    }

    @ViewBuilder private var image: some View {
        if let avatarURL = roomAvatarURL {
            WebImage(url: avatarURL)
                .resizable()
                .placeholder { prefixAvatar }
                .aspectRatio(contentMode: .fill)
        } else {
            prefixAvatar
        }
    }

    @Environment(\.sizeCategory) private var sizeCategory

    var body: some View {
        HStack(alignment: .center) {
            avatarView
            VStack(alignment: .leading, spacing: -4) {
                topView
                bottomView
            }.layoutPriority(1)
        }
        .padding(.vertical, 5 * sizeCategory.scalingFactor)
    }
}

struct RoomListItemView_Previews: PreviewProvider {
    static func unreadCount() -> UInt {
        guard Bool.random() else {
            return 0
        }
        // Random number between 10^0.0 and 10^4.0:
        return UInt(pow(10.0, Double.random(in: 0.0..<4.0)))
    }

    static var contentSizeList: some View {
        List {
            ForEach(ContentSizeCategory.allCases, id: \.self) { contentSizeCategory in
                RoomListItemView(
                    title: "Morpheus",
                    subtitle: "Red or blue 💊?",
                    rightDetail: "10m ago",
                    badge: unreadCount(),
                    roomAvatarURL: MXURL.nioIconURL
                )
                .environment(\.sizeCategory, contentSizeCategory)
            }
        }
    }

    static var contentList: some View {
        List {
            RoomListItemView(
                title: "Morpheus",
                subtitle: "",
                rightDetail: "10m ago",
                badge: 0,
                roomAvatarURL: MXURL.nioIconURL
            )
            RoomListItemView(
                title: "Morpheus",
                subtitle: "Red and yellow and pink and green. Purple and orange and blue 🌈.",
                rightDetail: "10m ago",
                badge: 0,
                roomAvatarURL: MXURL.nioIconURL
            )
            RoomListItemView(
                title: "Morpheus",
                subtitle: "Red or blue 💊?",
                rightDetail: "10m ago",
                badge: 50,
                roomAvatarURL: MXURL.nioIconURL
            )
        }
    }

    static var previews: some View {
        Group {
            contentSizeList
                .environment(\.colorScheme, .light)
            contentSizeList
                .environment(\.colorScheme, .dark)
            contentList
        }
        .accentColor(.purple)
    }
}
