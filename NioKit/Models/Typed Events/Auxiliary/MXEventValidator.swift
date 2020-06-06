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
            print("Expected \(String(reflecting: U.self)), found nil")
            throw MXEventValidationError.missingValue
        }
        guard let value = anyValue as? U else {
            print("Expected \(String(reflecting: U.self)), found \(String(reflecting: T.self))")
            throw MXEventValidationError.invalidType
        }
        guard value == expected else {
            print("Expected \(String(reflecting: expected)), found \(String(reflecting: value))")
            throw MXEventValidationError.invalidValue
        }
    }

    internal static func expect<T, U>(value: T, is type: U.Type) throws {
        guard value is U else {
            print("Expected \(String(reflecting: U.self)), found \(String(reflecting: T.self))")
            throw MXEventValidationError.invalidType
        }
    }

    internal static func expectNotNil<T>(value valueOrNil: T?) throws {
        guard valueOrNil != nil else {
            print("Expected \(String(reflecting: T.self)), found nil")
            throw MXEventValidationError.missingValue
        }
    }

    internal static func unwrap<T, U>(value valueOrNil: T?, as type: U.Type) throws -> U {
        guard let anyValue = valueOrNil else {
            print("Expected \(String(reflecting: U.self)), found nil")
            throw MXEventValidationError.missingValue
        }
        guard let value = anyValue as? U else {
            print("Expected \(String(reflecting: U.self)), found \(String(reflecting: T.self))")
            throw MXEventValidationError.invalidType
        }
        return value
    }

    internal static func ifPresent<T, U>(
        _ valueOrNil: T?,
        as type: U.Type,
        _ closure: (U) throws -> ()
    ) throws {
        guard let anyValue = valueOrNil else {
            return
        }
        guard let value = anyValue as? U else {
            print("Expected \(String(reflecting: U.self)), found \(String(reflecting: T.self))")
            throw MXEventValidationError.invalidType
        }
        try closure(value)
    }
}
