import Foundation
import SwiftMatrixSDK

struct EventCollection {
    var wrapped: [MXEvent]

    init(_ events: [MXEvent]) {
        self.wrapped = events
    }

    func connectedEdges(of event: MXEvent) -> ConnectedEdges {
        guard let idx = wrapped.firstIndex(of: event) else {
            fatalError("Event not found in EventCollection")
        }

        guard idx > wrapped.startIndex else {
            return .bottomEdge
        }

        guard
            let sender = event.sender,
            let preSender = wrapped[wrapped.index(before: idx)].sender
        else {
            return []
        }

        if sender != preSender {
            return .bottomEdge
        }

        guard
            idx < wrapped.endIndex - 1,
            let sucSender = wrapped[wrapped.index(after: idx)].sender
        else {
            return .topEdge
        }

        if sender != sucSender {
            return .topEdge
        } else if sender == preSender && sender != sucSender {
            return .topEdge
        } else if sender == preSender && sender == sucSender {
            return [.topEdge, .bottomEdge]
        }

        fatalError("Non-covered position case? \(sender) \(preSender) \(sucSender)")
    }
}

struct ConnectedEdges: OptionSet {
    let rawValue: Int

    static let topEdge: Self = .init(rawValue: 1 << 0)
    static let bottomEdge: Self = .init(rawValue: 1 << 1)
}
