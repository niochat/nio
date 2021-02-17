import SwiftUI

enum SFSymbol: String, View {
    case typing = "scribble.variable"
    case close = "xmark"

    var body: some View {
        Image(systemName: self.rawValue)
    }
}
