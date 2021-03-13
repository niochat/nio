import SwiftUI
import class MatrixSDK.MXEvent

struct RoomPowerLevelsEventView: View {
    struct ViewModel {
        fileprivate let sender: String

        struct LevelChange: Identifiable {
            let name: String
            let old: Int?
            let new: Int

            var id: String { name }

            private func levelName(_ level: Int) -> String {
                switch level {
                case 0: return L10n.RoomPowerLevel.default
                case 50: return L10n.RoomPowerLevel.moderator
                case 100: return L10n.RoomPowerLevel.admin
                default: return L10n.RoomPowerLevel.custom(level)
                }
            }

            fileprivate var oldLevelName: String {
                old.map { levelName($0) } ?? L10n.RoomPowerLevel.default
            }

            fileprivate var newLevelName: String {
                levelName(new)
            }
        }
        private let changes: [LevelChange]

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

        var combined: String {
            changes
                .map {
                    if sender == $0.name {
                        return L10n.Event.RoomPowerLevel.changeSelf(sender, $0.oldLevelName, $0.newLevelName)
                    }
                    return L10n.Event.RoomPowerLevel.changeOther(sender, $0.name, $0.oldLevelName, $0.newLevelName)
                }
                .joined(separator: "\n")
        }
    }

    let model: ViewModel

    var body: some View {
        GenericEventView(text: model.combined)
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
