import MatrixSDK
import SwiftUI

public protocol MXStringId: Hashable, Codable, ExpressibleByStringLiteral,
                     CustomStringConvertible, RawRepresentable {

var id : String { get }

init(_ id: String)
}

extension MXStringId {
    @inlinable
    public init(rawValue id: String) { self.init(id) }
    
    @inlinable
    public var rawValue : String { return id }
}

public extension MXStringId {
    
    @inlinable
    var description: String { return "<\(type(of: self)): \(id)>" }
}

public extension MXStringId { // Literals
    
    init(stringLiteral value: String) { self.init(value) }
}

public extension MXStringId {
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(try container.decode(String.self))
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }
}

public extension MXStringId {
    init<R>(_ id: R) where R: RawRepresentable, R.RawValue == String {
        self.init(id.rawValue)
    }
}

extension MXPublicRoom: Identifiable {}
extension MXRoom: Identifiable {
    public struct MXRoomId: MXStringId, Hashable {
        public var id: String
        
        public init(_ id: String) {
            self.id = id
        }
    }
    
    public var id: MXRoomId {
        get {
            return MXRoomId(self.roomId)
        }
    }
}
extension MXEvent: Identifiable {}
