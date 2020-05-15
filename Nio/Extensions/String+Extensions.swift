import Foundation

// FIXME: this seems like it could back-fire,
// encouraging the use of stringly-typed code.
extension String: Identifiable {
    public var id: String {
        self
    }
}
