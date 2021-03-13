import SwiftUI
import class MatrixSDK.MXEvent

struct RoomMemberEventView: View {
    struct ViewModel {
        private let sender: String

        struct User {
            let displayName: String
            let avatarURL: MXURL?
            let membership: String
            let reason: String?
        }

        fileprivate let current: User
        private let previous: User?

        var hasUserInfoDifference: Bool {
            guard let previous = previous else { return false }
            return current.displayName != previous.displayName
                || current.avatarURL?.mxContentURI != previous.avatarURL?.mxContentURI
        }

        init(sender: String,
             current: User,
             previous: User?) {
            self.sender = sender
            self.current = current
            self.previous = previous
        }

        init(event: MXEvent) {
            self.sender = event.sender

            self.current = User(
                // FIXME: This sometimes fails to show the correct display name
                // although I can clearly see it present in the event details in
                // Riot. Is the event metadata somehow different here?!
                displayName: event.content(valueFor: "displayname") ?? event.sender,
                avatarURL: event.content(valueFor: "avatar_url").flatMap(MXURL.init),
                membership: event.content(valueFor: "membership") ?? "",
                reason: event.content(valueFor: "reason")
            )

            if let prevDisplayname: String = event.prevContent(valueFor: "displayname"),
                let prevMembership: String = event.prevContent(valueFor: "membership"),
                let reason: String? = event.prevContent(valueFor: "reason")
            {
                let prevAvatarURL: MXURL? = event.prevContent(valueFor: "avatar_url").flatMap(MXURL.init)
                self.previous = User(displayName: prevDisplayname, avatarURL: prevAvatarURL, membership: prevMembership, reason: reason)
            } else {
                self.previous = nil
            }
        }

        var text: String {
            switch current.membership {
            case "invite":
                return L10n.Event.RoomMember.invited(sender, current.displayName)
            case "leave":
                return L10n.Event.RoomMember.left(current.displayName)
            case "ban":
                return L10n.Event.RoomMember.ban(sender, current.displayName)
            case "join":
                // FIXME: This flow is ridiculous.
                // Add tests (and refactor)!
                if hasUserInfoDifference, let previous = previous {
                    guard previous.membership != "invite" else {
                        return L10n.Event.RoomMember.joined(current.displayName)
                    }
                    if previous.displayName != current.displayName {
                        return L10n.Event.RoomMember.changeName(previous.displayName, current.displayName)
                    }
                    if let previousAvatarURL = previous.avatarURL {
                        if previousAvatarURL.mxContentURI != current.avatarURL?.mxContentURI {
                            if current.avatarURL == nil {
                                return L10n.Event.RoomMember.removeAvatar(current.displayName)
                            }
                            return L10n.Event.RoomMember.changeAvatar(previous.displayName)
                        } else {
                            return L10n.Event.RoomMember.unknownState("join event \(sender)")
                        }
                    } else {
                        return L10n.Event.RoomMember.setAvatar(current.displayName)
                    }
                } else {
                    return L10n.Event.RoomMember.joined(current.displayName)
                }
            default:
                return L10n.Event.RoomMember.unknownState("\(sender) \(current.membership)")
            }
        }
    }

    var model: ViewModel

    var body: some View {
        GenericEventView(text: model.text, image: model.current.avatarURL)
    }
}

struct RoomMemberEventView_Previews: PreviewProvider {
    static func user(name: String,
                     avatar: MXURL? = nil,
                     membership: String,
                     reason: String? = nil) -> RoomMemberEventView.ViewModel.User {
        .init(displayName: name, avatarURL: avatar, membership: membership, reason: reason)
    }

    static var previews: some View {
        VStack {
            RoomMemberEventView(model:
                .init(sender: "Jane Doe",
                      current: user(name: "John Doe", membership: "invite"),
                      previous: nil))
            RoomMemberEventView(model:
                .init(sender: "John doe",
                      current: user(name: "John Doe", membership: "join"),
                      previous: nil))
            RoomMemberEventView(model:
                .init(sender: "John Doe",
                      current: user(name: "John Doe", membership: "leave"),
                      previous: nil))
            RoomMemberEventView(model:
                .init(sender: "Jane Doe",
                      current: user(name: "Jane", membership: "join"),
                      previous: user(name: "Jane Doe", membership: "join")))
            RoomMemberEventView(model:
                .init(sender: "Jane",
                      current: user(name: "Jane", avatar: MXURL(mxContentURI: "mxc://uri"), membership: "join"),
                      previous: user(name: "Jane", membership: "join")))
            RoomMemberEventView(model:
                .init(sender: "Jane",
                      current: user(name: "Jane", avatar: MXURL(mxContentURI: "mxc://other"), membership: "join"),
                      previous: user(name: "Jane", avatar: MXURL(mxContentURI: "mxc://uri"), membership: "join")))
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
