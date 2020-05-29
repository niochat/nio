import SwiftMatrixSDK

public enum MXEventValidationError: Error {
    case notYetImplemented
    case invalid
    case other(_ message: String)
}

extension MXEventValidationError: CustomDebugStringConvertible {
    public var debugDescription: String {
        let message: String
        switch self {
        case .notYetImplemented:
            message = "Not yet implemented"
        case .invalid:
            message = "Invalid"
        case .other(let string):
            message = string
        }

        return """
        \(message)

        (Hint: Add a 'Swift Error Breakpoint' to find the exact failure source.)
        """
    }
}

internal struct MXEventValidator {
    typealias Error = MXEventValidationError

    internal static func expect<T, U: Equatable>(value valueOrNil: T, equals expected: U) throws {
        guard let value = valueOrNil as? U else {
            throw MXEventValidationError.invalid
        }
        guard value == expected else {
            throw MXEventValidationError.invalid
        }
    }

    internal static func expect<T, U>(value: T, is type: U.Type) throws {
        guard value is U else {
            throw MXEventValidationError.invalid
        }
    }

    internal static func expectNotNil<T>(value valueOrNil: T?) throws {
        guard valueOrNil != nil else {
            throw MXEventValidationError.invalid
        }
    }
}
