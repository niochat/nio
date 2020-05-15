import Foundation
import SwiftMatrixSDK

extension MXEvent {
    public var timestamp: Date {
        Date(timeIntervalSince1970: TimeInterval(self.originServerTs / 1000))
    }

    public func content<T>(valueFor key: String) -> T? {
        if let value = self.content?[key] as? T {
            return value
        }
        return nil
    }

    public func prevContent<T>(valueFor key: String) -> T? {
        if let value = self.unsignedData?.prevContent?[key] as? T {
            return value
        }
        return nil
    }
}
