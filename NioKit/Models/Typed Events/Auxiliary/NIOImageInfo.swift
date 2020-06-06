import SwiftMatrixSDK

public protocol NIOImageInfoProtocol {
    var height: Int? { get }

    var width: Int? { get }

    var mimeType: String? { get }

    var size: Int? { get }

    var thumbnailURL: URL? { get }

    // FIXME: give proper type?
    var thumbnailFile: [String: Any]? { get }

    // FIXME: give proper type?
    var thumbnailInfo: [String: Any]? { get }
}

public struct NIOImageInfo {
    fileprivate struct Key {
        static let height: String = "h"
        static let width: String = "w"
        static let mimeType: String = "mimetype"
        static let size: String = "size"
        static let thumbnailURL: String = "thumbnail_url"
        static let thumbnailFile: String = "thumbnail_file"
        static let thumbnailInfo: String = "thumbnail_info"
    }

    private let dictionary: [String: Any]

    public init(fromJSON dictionary: [String: Any]) throws {
        try MXEventValidator.validate(dictionary: dictionary, for: Self.self)

        self.dictionary = dictionary
    }
}

extension NIOImageInfo: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard (lhs as NIOImageInfoProtocol) == (rhs as NIOImageInfoProtocol) else {
            return false
        }
        return true
    }
}

extension NIOImageInfo: NIOImageInfoProtocol {
    public var height: Int? {
        // swiftlint:disable:next force_cast
        guard let heightString = self.dictionary[Key.height] as! String? else {
            return nil
        }
        return Int(heightString)
    }

    public var width: Int? {
        // swiftlint:disable:next force_cast
        guard let widthString = self.dictionary[Key.width] as! String? else {
            return nil
        }
        return Int(widthString)
    }

    public var mimeType: String? {
        self.dictionary[Key.mimeType] as? String
    }

    public var size: Int? {
        // swiftlint:disable:next force_cast
        guard let sizeString = self.dictionary[Key.size] as! String? else {
            return nil
        }
        return Int(sizeString)
    }

    public var thumbnailURL: URL? {
        // swiftlint:disable:next force_cast
        let urlString = self.dictionary[Key.thumbnailURL] as! String
        return URL(string: urlString)!
    }

    public var thumbnailFile: [String: Any]? {
        // swiftlint:disable:next force_cast
        self.dictionary[Key.thumbnailFile] as! [String: Any]?
    }

    public var thumbnailInfo: [String: Any]? {
        // swiftlint:disable:next force_cast
        self.dictionary[Key.thumbnailInfo] as! [String: Any]?
    }
}

extension MXEventValidator {
    internal static func validate(dictionary: [String: Any], for: NIOImageInfo.Type) throws {
        typealias Key = NIOImageInfo.Key

        try self.expect(value: dictionary[Key.height], is: String?.self)
        try self.expect(value: dictionary[Key.width], is: String?.self)
        try self.expect(value: dictionary[Key.mimeType], is: String?.self)
        try self.expect(value: dictionary[Key.size], is: String?.self)
        try self.expect(value: dictionary[Key.thumbnailURL], is: String?.self)
        try self.expect(value: dictionary[Key.thumbnailFile], is: [String: Any]?.self)
        try self.expect(value: dictionary[Key.thumbnailInfo], is: [String: Any]?.self)
    }
}

internal func == (lhs: NIOImageInfoProtocol, rhs: NIOImageInfoProtocol) -> Bool {
    guard lhs.height == rhs.height else {
        return false
    }
    guard lhs.width == rhs.width else {
        return false
    }
    guard lhs.mimeType == rhs.mimeType else {
        return false
    }
    guard lhs.size == rhs.size else {
        return false
    }
    guard lhs.thumbnailURL == rhs.thumbnailURL else {
        return false
    }
    guard lhs.thumbnailFile == rhs.thumbnailFile else {
        return false
    }
    guard lhs.thumbnailInfo == rhs.thumbnailInfo else {
        return false
    }
    return true
}
