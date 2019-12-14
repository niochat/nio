import Foundation

/// An iterator with a `peek()` that returns the next element
/// without removing it without advancing the iterator.
struct PeekableIterator<Iterator>: IteratorProtocol where Iterator: IteratorProtocol {
    typealias Element = Iterator.Element

    private var iterator: Iterator
    private var peeked: Element?

    /// Creates a peekable iterator, wrapping `iterator`.
    /// - Parameter iterator: the wrapped iterator
    init(_ iterator: Iterator) {
        self.iterator = iterator
    }

    /// Advances the iterator and returns the next value.
    mutating func next() -> Element? {
        guard let peeked = peeked else {
            return iterator.next()
        }
        defer { self.peeked = nil }
        return peeked
    }

    /// Returns the `next()` value without advancing the iterator.
    mutating func peek() -> Element? {
        if peeked == nil {
            peeked = iterator.next()
        }
        return peeked
    }
}
