import SwiftUI

struct RoomMemberEventView: View {
    let sender: String
    let affectedUser: String?
    let membership: String

    var text: String {
        switch membership {
        case "invite":
            return "\(sender) invited \(affectedUser ?? "n/a")"
        case "join":
            return "\(sender) joined"
        case "leave":
            return "\(sender) left"
        default:
            return "\(sender) \(membership)'d"
        }
    }

    var body: some View {
        HStack {
            Spacer()
            VStack {
                Text(text)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.vertical, 3)
    }
}

struct RoomMemberEventView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            RoomMemberEventView(sender: "Jane Doe", affectedUser: "John Doe", membership: "invite")
            RoomMemberEventView(sender: "John Doe", affectedUser: nil, membership: "join")
            RoomMemberEventView(sender: "John Doe", affectedUser: nil, membership: "leave")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
