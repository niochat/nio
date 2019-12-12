import Foundation
import SwiftMatrixSDK

struct EventCollection {
    var wrapped: [MXEvent]

    init(_ events: [MXEvent]) {
        self.wrapped = events
    }

    func position(of event: MXEvent) -> GroupPosition {
        guard let idx = wrapped.firstIndex(of: event) else {
            fatalError("Event not found in EventCollection")
        }

        guard idx > wrapped.startIndex else {
            return .start
        }

        guard
            let sender = event.sender,
            let preSender = wrapped[wrapped.index(before: idx)].sender
        else {
            return .notApplicable
        }

        if sender != preSender {
            return .start
        }

        guard
            idx < wrapped.endIndex - 1,
            let sucSender = wrapped[wrapped.index(after: idx)].sender
        else {
            return .end
        }

        if sender != sucSender {
            return .end
        } else if sender == preSender && sender != sucSender {
            return .end
        } else if sender == preSender && sender == sucSender {
            return .continuation
        }

        fatalError("Non-covered position case? \(sender) \(preSender) \(sucSender)")
    }
}

enum GroupPosition {
    case start
    case continuation
    case end
    case notApplicable

    var topMessagePadding: CGFloat {
        switch self {
        case .start:
            return 8
        case .continuation, .end:
            return 3
        case .notApplicable:
            return 10
        }
    }

    var showMessageSender: Bool {
        self == .start
    }
}

struct GroupBounds: OptionSet, Equatable, Hashable {
    let rawValue: Int

    static let isAtStartOfGroup: Self = .init(rawValue: 1 << 0)
    static let isAtEndOfGroup: Self = .init(rawValue: 1 << 1)

    static let isLone: Self = [.isAtStartOfGroup, .isAtEndOfGroup]
}
