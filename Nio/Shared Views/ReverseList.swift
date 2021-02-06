import SwiftUI
import UIKit

struct ReverseList<Element, Content>: View where Element: Identifiable, Content: View {
    var items: [Element]
    var reverseItemOrder: Bool
    var viewForItem: (Element) -> Content

    init(_ items: [Element], reverseItemOrder: Bool = true, viewForItem: @escaping (Element) -> Content) {
        self.items = items
        self.reverseItemOrder = reverseItemOrder
        self.viewForItem = viewForItem
    }

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(reverseItemOrder ? items.reversed() : items) { item in
                    self.viewForItem(item)
                        .scaleEffect(x: -1.0, y: 1.0)
                        .rotationEffect(.degrees(180))
                }
            }
        }
        .scaleEffect(x: -1.0, y: 1.0)
        .rotationEffect(.degrees(180))
    }
}

struct ReverseList_Previews: PreviewProvider {
    static var previews: some View {
        ReverseList(["1", "2", "3"]) {
            Text($0)
        }
    }
}
