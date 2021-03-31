import SwiftUI

public class SFIconPack: DefaultIconPack {
    private struct IconPerson: View {
        var body: some View {
            Image(systemName: "person.crop.circle")
                .font(Font.system(.title))
                .accessibility(label: Text(verbatim: L10n.RecentRooms.AccessibilityLabel.settings))
                .foregroundColor(.accentColor)
        }
    }

    private struct IconNewChat: View {
        var body: some View {
            Image(systemName: "square.and.pencil")
                .font(Font.system(.title))
                .accessibility(label: Text(verbatim: L10n.RecentRooms.AccessibilityLabel.newConversation))
                .foregroundColor(.accentColor)
        }
    }

    private struct IconAttachment: View {
        var body: some View {
            Image(systemName: "paperclip")
                .font(Font.system(.title))
                .accessibility(label: Text(verbatim: L10n.Composer.AccessibilityLabel.sendFile))
        }
    }

    private struct IconSendMessage: View {
        var body: some View {
            Image(systemName: "arrow.up.circle.fill")
                .font(Font.system(.title))
                .accessibility(label: Text(verbatim: L10n.Composer.AccessibilityLabel.send))
        }
    }

    private struct IconReaction: View {
        var body: some View {
            Image(systemName: "face.smiling")
                .font(Font.system(.title))
        }
    }

    private struct IconReply: View {
        var body: some View {
            Image(systemName: "arrowshape.turn.up.forward")
                .font(Font.system(.title))
        }
    }

    private struct IconEdit: View {
        var body: some View {
            Image(systemName: "pencil")
                .font(Font.system(.title))
        }
    }

    private struct IconRedact: View {
        var body: some View {
            Image(systemName: "trash")
                .font(Font.system(.title))
        }
    }

    public override var getIconPerson: AnyView {
        return AnyView(IconPerson())
    }

    public override var getIconNewChat: AnyView {
        return AnyView(IconNewChat())
    }

    public override var getIconAttachment: AnyView {
        return AnyView(IconAttachment())
    }

    public override var getIconSendMessage: AnyView {
        return AnyView(IconSendMessage())
    }

    public override var getIconReaction: AnyView {
        return AnyView(IconReaction())
    }

    public override var getIconReply: AnyView {
        return AnyView(IconReply())
    }

    public override var getIconEdit: AnyView {
        return AnyView(IconEdit())
    }

    public override var getIconRedact: AnyView {
        return AnyView(IconRedact())
    }
}
