import Foundation
import SwiftMatrixSDK

extension MXEvent {
    var timestamp: Date {
        Date(timeIntervalSince1970: TimeInterval(self.originServerTs / 1000))
    }

    func content<T>(valueFor key: String) -> T? {
        if let value = self.content?[key] as? T {
            return value
        }
        return nil
    }

    func prevContent<T>(valueFor key: String) -> T? {
        if let value = self.unsignedData?.prevContent?[key] as? T {
            return value
        }
        return nil
    }
}
