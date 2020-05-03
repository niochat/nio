import SwiftMatrixSDK

// Implementation heavily inspired by [Messagerie](https://github.com/manuroe/messagerie).

extension MXRoomSummary {
    // swiftlint:disable:next identifier_name
    var nio_lastEvent: Event? {
        get {
            guard let data = self.others?["chat.nio.lastMessage"] as? Data else { return nil }
            return try? JSONDecoder().decode(Event.self, from: data)
        }
        set {
            self.others["chat.nio.lastMessage"] = try? JSONEncoder().encode(newValue)
        }
    }
}
