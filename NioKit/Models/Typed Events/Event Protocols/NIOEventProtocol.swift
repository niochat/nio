import SwiftMatrixSDK

/// Event \
/// ([API Schema](https://github.com/matrix-org/matrix-doc/blob/master/event-schemas/schema/core-event-schema/event.yaml))
///
/// The basic set of fields all events must have.
public protocol NIOEventProtocol {
    /// The type of event. This SHOULD be namespaced similar to Java package
    /// naming conventions e.g. 'com.example.subdomain.event.type'
    var type: String { get }

    /// The fields in this object will vary depending on the type of event.
    /// When interacting with the REST API, this is the HTTP body.
    var content: [String: Any] { get }
}

extension NIOEventProtocol where Self: MXEventProvider {
    public var type: String {
        self.event.wireType
    }

    public var content: [String: Any] {
        self.event.content
    }
}

extension MXEventValidator {
    internal static func validate(event: MXEvent, for: NIOEventProtocol.Protocol) throws {
        struct Key {
            static let type: String = "type"
            static let content: String = "content"
        }

        try self.expect(value: event.type, is: String.self)
        try self.expect(value: event.content, is: [String: Any].self)
    }
}
