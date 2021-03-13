import SwiftUI

struct IsVisibleKey: PreferenceKey {
    static var defaultValue: Bool = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
}

struct ReverseList<Element, Content>: View where Element: Identifiable, Content: View {
    private let items: [Element]
    private let reverseItemOrder: Bool
    private let viewForItem: (Element) -> Content

    @Binding var hasReachedTop: Bool

    init(_ items: [Element], reverseItemOrder: Bool = true, hasReachedTop: Binding<Bool>, viewForItem: @escaping (Element) -> Content) {
        self.items = items
        self.reverseItemOrder = reverseItemOrder
        self._hasReachedTop = hasReachedTop
        self.viewForItem = viewForItem
    }

    var body: some View {
        GeometryReader { contentsGeometry in
            ScrollView {
                ForEach(reverseItemOrder ? items.reversed() : items) { item in
                    self.viewForItem(item)
                        .scaleEffect(x: -1.0, y: 1.0)
                        .rotationEffect(.degrees(180))
                }
                GeometryReader { topViewGeometry in
                    let frame = topViewGeometry.frame(in: .global)
                    let isVisible = contentsGeometry.frame(in: .global).contains(CGPoint(x: frame.midX, y: frame.midY))

                    HStack {
                        Spacer()
                        ProgressView().progressViewStyle(CircularProgressViewStyle())
                        Spacer()
                    }
                    .preference(key: IsVisibleKey.self, value: isVisible)
                }
                .frame(height: 30)      // FIXME: Frame height shouldn't be hard-coded
                .onPreferenceChange(IsVisibleKey.self) {
                    hasReachedTop = $0
                }
            }
            .scaleEffect(x: -1.0, y: 1.0)
            .rotationEffect(.degrees(180))
        }
    }
}

struct ReverseList_Previews: PreviewProvider {
    static var previews: some View {
        ReverseList(["1", "2", "3"], hasReachedTop: .constant(false)) {
            Text($0)
        }
    }
}
