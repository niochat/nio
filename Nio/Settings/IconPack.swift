import SwiftUI

struct IconPackStruct: Identifiable, View {
    let title: String
    let pack: DefaultIconPack

    var id: String {
        title
    }

    init(title: String) {
        self.title = title
        self.pack = IconPackTitle.alternativeClasses[IconPackTitle.alternatives.firstIndex(of: title)!]
    }

    var body: some View {
        HStack {
            self.pack.getIconPerson
            Text(title)
        }
    }
}

protocol IconPackProtocol {
    associatedtype Body: View
    var getIconPerson: Body { get }
    var getIconNewChat: Body { get }
    var getIconAttachment: Body { get }
    var getIconSendMessage: Body { get }
    var getIconReaction: Body { get }
    var getIconReply: Body { get }
    var getIconEdit: Body { get }
    var getIconRedact: Body { get }
}

class IconPack {
    public let pack: DefaultIconPack

    init(title: String) {
        self.pack = IconPackTitle.alternativeClasses[IconPackTitle.alternatives.firstIndex(of: title)!]
    }
}

class IconPackTitle: ObservableObject {
    static var alternatives = [
        "Default (nio)",
        "SF Symbols",
    ]

    static var alternativeClasses = [
        DefaultIconPack(),
        SFIconPack(),
    ]
}
