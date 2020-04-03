import Foundation

protocol CustomEvent {
    func encodeContent() throws -> [String: Any]
}
