import XCTest

@testable import Nio

class PeekableIteratorTests: XCTestCase {
    func testNextShouldRemoveAndReturnNextElement() {
        let elements = [0, 1, 2, 3, 4]
        let iterator = elements.makeIterator()
        var peekableIterator = PeekableIterator(iterator)

        let actual0 = peekableIterator.next()
        let expected0 = 0
        XCTAssertEqual(actual0, expected0)

        let actual1 = peekableIterator.next()
        let expected1 = 1
        XCTAssertEqual(actual1, expected1)
    }

    func testPeekShouldReturnButNotRemoveNextElement() {
        let elements = [0, 1, 2, 3, 4]
        let iterator = elements.makeIterator()
        var peekableIterator = PeekableIterator(iterator)

        // Calling peek should return the next element:
        let actual0 = peekableIterator.peek()
        let expected0 = 0
        XCTAssertEqual(actual0, expected0)

        // Calling peek again should return the same element:
        let actual1 = peekableIterator.peek()
        let expected1 = 0
        XCTAssertEqual(actual1, expected1)
    }

    func testNextAfterPeekShouldRemoveAndReturnPeekedElement() {
        let elements = [0, 1, 2, 3, 4]
        let iterator = elements.makeIterator()
        var peekableIterator = PeekableIterator(iterator)

        // Calling peek should return the next element:
        let actual0 = peekableIterator.peek()
        let expected0 = 0
        XCTAssertEqual(actual0, expected0)

        // Calling next should return the peeked element:
        let actual1 = peekableIterator.next()
        let expected1 = 0
        XCTAssertEqual(actual1, expected1)
    }

    func testPeekAfterNextShouldRemoveAndReturnPeekedElement() {
        let elements = [0, 1, 2, 3, 4]
        let iterator = elements.makeIterator()
        var peekableIterator = PeekableIterator(iterator)

        // Calling next should return the next element:
        let actual0 = peekableIterator.next()
        let expected0 = 0
        XCTAssertEqual(actual0, expected0)

        // Calling peek should return the next element:
        let actual1 = peekableIterator.peek()
        let expected1 = 1
        XCTAssertEqual(actual1, expected1)
    }
}
