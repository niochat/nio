import SwiftUI
import SwiftMatrixSDK
import SDWebImageSwiftUI

import NioKit

struct RoomListItemContainerView: View {
    @EnvironmentObject var store: AccountStore

    var room: NIORoom

    var body: some View {
        let roomName = room.summary.displayname ?? ""
        let lastMessage = room.lastMessage
        let lastActivity = Formatter.string(forRelativeDate: room.summary.lastMessageDate)

        var accessibilityLabel = ""
        if room.isDirect {
            accessibilityLabel = L10n.RecentRooms.AccessibilityLabel.dm(roomName, lastActivity, lastMessage)
        } else {
            accessibilityLabel = L10n.RecentRooms.AccessibilityLabel.room(roomName, lastActivity, lastMessage)
        }

        var roomAvatarURL: URL?
        if let client = store.client,
            let homeserver = URL(string: client.homeserver),
            let avatar = room.summary.avatar {
                roomAvatarURL = MXURL(mxContentURI: avatar)?.contentURL(on: homeserver)
        }

        return RoomListItemView(title: room.summary.displayname ?? "",
                                subtitle: lastMessage,
                                rightDetail: lastActivity,
                                badge: room.summary.localUnreadEventCount,
                                roomAvatarURL: roomAvatarURL)
        .accessibility(label: Text(accessibilityLabel))
    }
}

struct RoomListItemView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @Environment(\.colorSchemeContrast) var colorSchemeContrast: ColorSchemeContrast

    var title: String
    var subtitle: String
    var rightDetail: String
    var badge: UInt
    var roomAvatarURL: URL?

    var gradient: LinearGradient {
        let color: Color = .white
        let colors = [color.opacity(0.3), color.opacity(0.0)]
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var prefixAvatar: some View {
        GeometryReader { geometry in
            Text(title.prefix(2).uppercased())
                .multilineTextAlignment(.center)
                .font(.system(.headline, design: .rounded))
                .lineLimit(1)
                .allowsTightening(true)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .foregroundColor(.init(UIColor.textOnAccentColor(for: colorScheme)))
                .background(
                    Color.accentColor.overlay(gradient)
                )
        }
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
            .lineLimit(1)
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
            .lineLimit(1)
            .allowsTightening(true)
            .foregroundColor(.secondary)
    }

    var badgeView: some View {
        Text(String(self.badge))
            .font(.caption)
            .lineLimit(1)
            .allowsTightening(true)
            .foregroundColor(.init(UIColor.textOnAccentColor(for: colorScheme)))
            // Make sure we get enough "breathing air" around the number:
            .padding(.vertical, 3 * sizeCategory.scalingFactor)
            .padding(.horizontal, 6 * sizeCategory.scalingFactor)
            .accessibility(label: Text(L10n.RecentRooms.AccessibilityLabel.newMessageBadge(Int(self.badge))))
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

    var image: some View {
        if let avatarURL = roomAvatarURL {
            return AnyView(
                WebImage(url: avatarURL)
                    .resizable()
                    .placeholder { prefixAvatar }
                    .aspectRatio(contentMode: .fill)
            )
        } else {
            return AnyView(
                prefixAvatar
            )
        }
    }

    @Environment(\.sizeCategory) var sizeCategory

    var body: some View {
        HStack(alignment: .center) {
            Circle()
                .foregroundColor(.clear)
                .aspectRatio(1, contentMode: .fill)
                .overlay(image.mask(Circle()))

            VStack(alignment: .leading, spacing: 0) {
                topView
                bottomView
            }.layoutPriority(1)
        }
        .padding([.vertical], 5 * sizeCategory.scalingFactor)
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

    static var list: some View {
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
