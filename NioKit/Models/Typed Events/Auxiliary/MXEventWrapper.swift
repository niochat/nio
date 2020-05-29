import SwiftMatrixSDK

public protocol MXEventInitializable {
    init(event: MXEvent) throws
}

public protocol MXEventProvider {
    var event: MXEvent { get }
}
