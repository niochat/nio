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
            return .leading
        }

        guard
            let sender = event.sender,
            let preSender = wrapped[wrapped.index(before: idx)].sender
        else {
            return .lone
        }

        if sender != preSender {
            return .leading
        }

        guard
            idx < wrapped.endIndex - 1,
            let sucSender = wrapped[wrapped.index(after: idx)].sender
        else {
            return .trailing
        }

        if sender != sucSender {
            return .trailing
        } else if sender == preSender && sender != sucSender {
            return .trailing
        } else if sender == preSender && sender == sucSender {
            return .center
        }

        fatalError("Non-covered position case? \(sender) \(preSender) \(sucSender)")
    }
}

enum GroupPosition {
    case leading
    case center
    case trailing
    case lone

    var isLeading: Bool {
        switch self {
        case .leading, .lone: return true
        case _: return false
        }
    }

    var isTrailing: Bool {
        switch self {
        case .trailing, .lone: return true
        case _: return false
        }
    }

    // FIXME: remove once we have proper message grouping:
    var topMessagePadding: CGFloat {
        switch self {
        case .leading:
            return 8
        case .center, .trailing:
            return 3
        case .lone:
            return 10
        }
    }

    // FIXME: remove once we have proper message grouping:
    var showMessageSender: Bool {
        self == .leading
    }
}
