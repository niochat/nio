import Foundation
import class SwiftMatrixSDK.MXEvent

class MockEvent: MXEvent {
    init(sender: String, type: String, timestamp: UInt64, isRedacted: Bool) {
        self._type = type
        self.isRedacted = isRedacted
        super.init()
        self.sender = sender
        self.originServerTs = 1000 * timestamp
    }

    // swiftlint:disable:next identifier_name
    var _type: String
    override var type: String! {
        _type
    }

    var isRedacted: Bool
    override func isRedactedEvent() -> Bool {
        isRedacted
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
