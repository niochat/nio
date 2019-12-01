import SwiftUI

extension ContentSizeCategory {
    var scalingFactor: CGFloat {
        switch self {
        case .extraSmall:
            return 0.8
        case .small:
            return 0.9
        case .medium:
            return 1.0
        case .large:
            return 1.1
        case .extraLarge:
            return 1.2
        case .extraExtraLarge:
            return 1.3
        case .extraExtraExtraLarge:
            return 1.4
        case .accessibilityMedium:
            return 1.5
        case .accessibilityLarge:
            return 1.6
        case .accessibilityExtraLarge:
            return 1.7
        case .accessibilityExtraExtraLarge:
            return 1.8
        case .accessibilityExtraExtraExtraLarge:
            return 1.9
        @unknown default:
            return 0.0
        }
    }
}
