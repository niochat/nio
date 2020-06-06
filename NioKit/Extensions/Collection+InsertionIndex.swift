import Foundation

extension Collection where Element: Comparable {
    public func insertionIndex(of value: Element) -> Index {
        self.insertionIndex(
            of: value,
            keyPath: \.self,
            by: { $0 < $1 }
        )
    }

    public func insertionIndex(
        of value: Element,
        by areInIncreasingOrder: (Element, Element) -> Bool
    ) -> Index {
        self.insertionIndex(
            of: value,
            keyPath: \.self,
            by: areInIncreasingOrder
        )
    }
}

extension Collection {
    public func insertionIndex<T>(
        of value: T,
        keyPath: KeyPath<Element, T>
    ) -> Index
    where
        T: Comparable
    {
        self.insertionIndex(
            of: value,
            keyPath: keyPath,
            by: { $0 < $1 }
        )
    }

    /// Search for lower bound of `value` within `self`.
    ///
    /// - Complexity: O(`log2(collection.count)`).
    ///
    /// - Parameters:
    ///   - value: The value to search for
    /// - Returns:
    ///   First index of the first `element` in `collection` for
    ///   which `element < value` evaluates to false or `nil` if `value` is not found.
    public func insertionIndex<T>(
        of value: T,
        keyPath: KeyPath<Element, T>,
        by areInIncreasingOrder: (T, T) -> Bool
    ) -> Index {
        var first = self.startIndex
        var index = first
        var count = self.count
        while count > 0 {
            index = first
            let step = count / 2
            index = self.index(index, offsetBy: step)
            let lhs = self[index][keyPath: keyPath]
            if areInIncreasingOrder(lhs, value) {
                first = self.index(after: index)
                count -= step + 1
            } else {
                count = step
            }
        }
        return first
    }
}
