import XCTest

@testable import Nio

class GroupingIteratorTests: XCTestCase {
    func testGroupingIteratorShouldSplitElementsByClosure() {
        let elements: [Int] = [0, 1, 3, 2, 3]
        let iterator = elements.makeIterator()
        let groupingIterator: GroupingIterator = .init(iterator) {
            // Group elements by their even/odd-ness:
            ($0 % 2) == ($1 % 2)
        }

        let expected: [[Int]] = [
            [0],
            [1, 3],
            [2],
            [3]
        ]
        let actual = Array(IteratorSequence(groupingIterator))
        XCTAssertEqual(actual, expected)
    }
}
