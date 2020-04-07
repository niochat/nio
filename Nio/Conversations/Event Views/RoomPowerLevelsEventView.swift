import SwiftUI
import class SwiftMatrixSDK.MXEvent

struct RoomPowerLevelsEventView: View {
    struct ViewModel {
        let sender: String

        struct LevelChange: Identifiable {
            let name: String
            let old: Int?
            let new: Int

            var id: String { name }

            private func levelName(_ level: Int) -> String {
                switch level {
                case 0: return "Default"
                case 50: return "Moderator"
                case 100: return "Admin"
                default: return "Custom (\(level))"
                }
            }

            var oldName: String {
                old.map { levelName($0) } ?? "Default"
            }

            var newName: String {
                levelName(new)
            }
        }
        let changes: [LevelChange]

        init(sender: String,
             changes: [LevelChange]) {
            self.sender = sender
            self.changes = changes
        }

        init(event: MXEvent) {
            let previousUsers = (event.unsignedData?.prevContent?["users"] as? [String: Int]) ?? [:]
            let currentUsers = (event.content?["users"] as? [String: Int]) ?? [:]

            var changes: [LevelChange] = []
            for (user, level) in currentUsers {
                if let oldLevel = previousUsers[user] {
                    if oldLevel != level {
                        changes.append(LevelChange(name: user,
                                                   old: oldLevel,
                                                   new: level))
                    }
                } else {
                    changes.append(LevelChange(name: user,
                                               old: nil,
                                               new: level))
                }
            }

            let sender = event.sender ?? ""
            self.init(sender: sender, changes: changes)
        }
    }

    var model: ViewModel

    var body: some View {
        VStack {
            ForEach(model.changes) { change in
                Text("\(self.model.sender) changed the power level of \(change.name) from \(change.oldName) to \(change.newName).")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 3)
    }
}

struct RoomPowerLevelsEventView_Previews: PreviewProvider {
    static var previews: some View {
        RoomPowerLevelsEventView(model: .init(
            sender: "Jane",
            changes: [
                .init(name: "John", old: nil, new: 50),
                .init(name: "John", old: 50, new: 100),
            ]))
        .previewLayout(.sizeThatFits)
    }
}
