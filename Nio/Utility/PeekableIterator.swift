import Foundation

struct PeekableIterator<Iterator>: IteratorProtocol where Iterator: IteratorProtocol {
    typealias Element = Iterator.Element

    private var iterator: Iterator
    private var peeked: Element?

    init(_ iterator: Iterator) {
        self.iterator = iterator
    }

    mutating func next() -> Element? {
        guard let peeked = peeked else {
            return iterator.next()
        }
        defer { self.peeked = nil }
        return peeked
    }

    mutating func peek() -> Element? {
        if peeked == nil {
            peeked = iterator.next()
        }
        return peeked
    }
}
