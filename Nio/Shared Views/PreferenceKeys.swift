import SwiftUI

struct ContentSizeThatFitsKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct BoolKey: PreferenceKey {
    static var defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
}
