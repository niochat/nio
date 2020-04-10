import SwiftUI
import class SwiftMatrixSDK.MXEvent

struct RoomMemberEventView: View {
    struct ViewModel {
        let sender: String

        struct User {
            let displayName: String
            let avatarURL: MXURL?
            let membership: String
        }

        let current: User
        let previous: User?

        var hasUserInfoDifference: Bool {
            guard let previous = previous else { return false }
            return current.displayName == previous.displayName
                || current.avatarURL?.mxContentURI == previous.avatarURL?.mxContentURI
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
                membership: event.content(valueFor: "membership") ?? ""
            )

            if let prevDisplayname: String = event.prevContent(valueFor: "displayname"),
                let prevMembership: String = event.prevContent(valueFor: "membership") {
                let prevAvatarURL: MXURL? = event.prevContent(valueFor: "avatar_url").flatMap(MXURL.init)
                self.previous = User(displayName: prevDisplayname, avatarURL: prevAvatarURL, membership: prevMembership)
            } else {
                self.previous = nil
            }
        }
    }

    var model: ViewModel

    var text: String {
        switch model.current.membership {
        case "invite":
            return "\(model.sender) invited \(model.current.displayName)"
        case "leave":
            return "\(model.current.displayName) left"
        case "join":
            // FIXME: This flow is ridiculous.
            if model.hasUserInfoDifference, let previous = model.previous {
                guard previous.membership != "invite" else {
                    return "\(model.current.displayName) joined"
                }
                if previous.displayName != model.current.displayName {
                    return "\(previous.displayName) changed their display name to \(model.current.displayName)"
                }
                if let previousAvatarURL = previous.avatarURL {
                    if previousAvatarURL.mxContentURI != model.current.avatarURL?.mxContentURI {
                        if model.current.avatarURL == nil {
                            return "\(model.current.displayName) removed their profile picture"
                        }
                        return "\(previous.displayName) updated their profile picture"
                    } else {
                        return "Unknown join state event: \(model.sender)"
                    }
                } else {
                    return "\(model.current.displayName) set their profile picture"
                }
            } else {
                return "\(model.current.displayName) joined"
            }
        default:
            return "Unknown state event: \(model.sender) \(model.current.membership)"
        }
    }

    var body: some View {
        GenericEventView(text: text)
    }
}

struct RoomMemberEventView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            RoomMemberEventView(model:
                .init(sender: "Jane Doe",
                      current: .init(displayName: "John Doe", avatarURL: nil, membership: "invite"),
                      previous: nil))
            RoomMemberEventView(model:
                .init(sender: "John doe",
                      current: .init(displayName: "John Doe", avatarURL: nil, membership: "join"),
                      previous: nil))
            RoomMemberEventView(model:
                .init(sender: "John Doe",
                      current: .init(displayName: "John Doe", avatarURL: nil, membership: "leave"),
                      previous: nil))
            RoomMemberEventView(model:
                .init(sender: "Jane Doe",
                      current: .init(displayName: "Jane", avatarURL: nil, membership: "join"),
                      previous: .init(displayName: "Jane Doe", avatarURL: nil, membership: "join")))
            RoomMemberEventView(model:
                .init(sender: "Jane",
                      current: .init(displayName: "Jane", avatarURL: MXURL(mxContentURI: "uri"), membership: "join"),
                      previous: .init(displayName: "Jane", avatarURL: nil, membership: "join")))
            RoomMemberEventView(model:
                .init(sender: "Jane",
                      current: .init(displayName: "Jane", avatarURL: MXURL(mxContentURI: "other uri"), membership: "join"),
                      previous: .init(displayName: "Jane", avatarURL: MXURL(mxContentURI: "uri"), membership: "join")))
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
