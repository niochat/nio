import SwiftMatrixSDK

public enum MXEventValidationError: Error {
    case invalidType
    case invalidValue
    case missingValue
}

extension MXEventValidationError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidType: return "Invalid Type"
        case .invalidValue: return "Invalid Value"
        case .missingValue: return "Missing Value"
        }
    }
}

extension MXEventValidationError: CustomDebugStringConvertible {
    public var debugDescription: String {
        return """
        Validation failed: \(self.description)

        (Hint: Add a 'Swift Error Breakpoint' to find the exact failure source.)
        """
    }
}

internal struct MXEventValidator {
    typealias Error = MXEventValidationError

    internal static func expect<T, U: Equatable>(value valueOrNil: T?, equals expected: U) throws {
        guard let anyValue = valueOrNil else {
            throw MXEventValidationError.missingValue
        }
        guard let value = anyValue as? U else {
            throw MXEventValidationError.invalidType
        }
        guard value == expected else {
            throw MXEventValidationError.invalidValue
        }
    }

    internal static func expect<T, U>(value: T, is type: U.Type) throws {
        guard value is U else {
            throw MXEventValidationError.invalidType
        }
    }

    internal static func expectNotNil<T>(value valueOrNil: T?) throws {
        guard valueOrNil != nil else {
            throw MXEventValidationError.missingValue
        }
    }
}
