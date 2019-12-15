import Foundation

/// An iterator with a grouping closure that returns sub-sequences next element
/// without removing it without advancing the iterator.
struct GroupingIterator<Iterator>: IteratorProtocol where Iterator: IteratorProtocol {
    typealias Element = [Iterator.Element]
    typealias Closure = (Iterator.Element, Iterator.Element) -> Bool

    private var iterator: PeekableIterator<Iterator>
    private let closure: Closure

    /// Creates an grouping iterator, wrapping `iterator`.
    /// - Parameters:
    ///   - iterator: the wrapped iterator
    ///   - closure: A predicate that returns true if its second argument
    ///              should be added to the same group as the first argument;
    ///              otherwise, false.
    init(_ iterator: Iterator, by closure: @escaping Closure) {
        self.iterator = .init(iterator)
        self.closure = closure
    }

    mutating func next() -> Element? {
        guard var previous = iterator.next() else {
            return nil
        }

        var group: [Iterator.Element] = [previous]

        while let peek = iterator.peek() {
            guard closure(previous, peek) else {
                break
            }

            // The forced unwrap is safe here, due to having peeked above:
            let element = iterator.next()!

            group.append(element)

            previous = element
        }

        return group
    }
}
