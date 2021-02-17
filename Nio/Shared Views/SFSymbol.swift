import SwiftUI

enum SFSymbol: String, View {
    case ellipsis
    case close = "xmark"

    var body: some View {
        Image(systemName: self.rawValue)
    }
}
