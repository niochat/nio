import SwiftUI

enum SFSymbol: String, View {
    case typing          = "scribble.variable"
    case close           = "xmark"

    case newConversation = "square.and.pencil"
    case settings        = "gear"
    case send            = "paperplane"
    case attach          = "paperclip"

    var body: some View {
        Image(systemName: self.rawValue)
    }
}
