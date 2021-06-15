import Foundation
import MatrixSDK

public extension MXEvent {
    var timestamp: Date {
        Date(timeIntervalSince1970: TimeInterval(originServerTs / 1000))
    }

    func content<T>(valueFor key: String) -> T? {
        if let value = content?[key] as? T {
            return value
        }
        return nil
    }

    func prevContent<T>(valueFor key: String) -> T? {
        if let value = unsignedData?.prevContent?[key] as? T {
            return value
        }
        return nil
    }
}
