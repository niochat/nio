import SwiftUI

public class DefaultIconPack: IconPackProtocol {
    private struct IconPerson: View {
        var body: some View {
            Image(Asset.Icon.user.name)
                .resizable()
                .frame(width: 30.0, height: 30.0)
                .accessibility(label: Text(verbatim: L10n.RecentRooms.AccessibilityLabel.settings))
                .foregroundColor(.accentColor)
        }
    }

    private struct IconNewChat: View {
        var body: some View {
            Image(Asset.Icon.addRoom.name)
                .resizable()
                .frame(width: 30.0, height: 30.0)
                .accessibility(label: Text(verbatim: L10n.RecentRooms.AccessibilityLabel.newConversation))
        }
    }

    private struct IconAttachment: View {
        var body: some View {
            Image(Asset.Icon.paperclip.name)
                .resizable()
                .frame(width: 30.0, height: 30.0)
                .accessibility(label: Text(verbatim: L10n.Composer.AccessibilityLabel.sendFile))
        }
    }

    private struct IconSendMessage: View {
        var body: some View {
            Image(Asset.Icon.paperplane.name)
                .resizable()
                .frame(width: 30.0, height: 30.0)
                .accessibility(label: Text(verbatim: L10n.Composer.AccessibilityLabel.send))
        }
    }

    private struct IconReaction: View {
        var body: some View {
            Image(Asset.Icon.smiley.name)
                .resizable()
                .frame(width: 30.0, height: 30.0)
        }
    }

    private struct IconReply: View {
        var body: some View {
            Image(Asset.Icon.Arrow.upLeft.name)
                .resizable()
                .frame(width: 30.0, height: 30.0)
        }
    }

    private struct IconEdit: View {
        var body: some View {
            Image(Asset.Icon.pencil.name)
                .resizable()
                .frame(width: 30.0, height: 30.0)
        }
    }

    private struct IconRedact: View {
        var body: some View {
            Image(Asset.Icon.trash.name)
                .resizable()
                .frame(width: 30.0, height: 30.0)
        }
    }

    public var getIconPerson: AnyView {
        return AnyView(IconPerson())
    }

    public var getIconNewChat: AnyView {
        return AnyView(IconNewChat())
    }

    public var getIconAttachment: AnyView {
        return AnyView(IconAttachment())
    }

    public var getIconSendMessage: AnyView {
        return AnyView(IconSendMessage())
    }

    public var getIconReaction: AnyView {
        return AnyView(IconReaction())
    }

    public var getIconReply: AnyView {
        return AnyView(IconReply())
    }

    public var getIconEdit: AnyView {
        return AnyView(IconEdit())
    }

    public var getIconRedact: AnyView {
        return AnyView(IconRedact())
    }
}
