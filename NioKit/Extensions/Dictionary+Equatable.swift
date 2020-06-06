import Foundation

/// A best-effort implementation of `Equatable` for `[String: Any]?`:
internal func == (lhs: [String: Any]?, rhs: [String: Any]?) -> Bool {
    switch (lhs, rhs) {
    case let (lhs?, rhs?):
        return lhs == rhs
    case (nil, nil):
        return true
    case _:
        return false
    }
}

/// A best-effort implementation of `Equatable` for `[String: Any]`:
internal func == (lhs: [String: Any], rhs: [String: Any]) -> Bool {
    let (lhsKeys, rhsKeys) = (lhs.keys, rhs.keys)
    guard lhsKeys.count == rhsKeys.count else {
        return false
    }
    return lhsKeys.sorted() == rhsKeys.sorted()
}
