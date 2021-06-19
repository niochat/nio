//
//  MXRoom+Asnyc.swift
//  Masui
//
//  Created by Finn Behrens on 11.06.21.
//

import Foundation
import MatrixSDK

extension MXRoom {
    func members() async throws -> MXRoomMembers? {
        try await withCheckedThrowingContinuation { continuation in
            self.members(completion: { resp in
                switch resp {
                case let .success(v):
                    continuation.resume(returning: v)
                case let .failure(e):
                    continuation.resume(throwing: e)
                @unknown default:
                    continuation.resume(throwing: NioUnknownContinuationSwitchError(value: resp))
                }
            })
        }
    }

    var liveTimeline: MXEventTimeline {
        get async {
            await withCheckedContinuation { continuation in
                self.liveTimeline { continuation.resume(returning: $0!) }
            }
        }
    }
    
    @discardableResult
    func sendTextMessage(_ text: String, formattedText: String? = nil, localEcho: inout MXEvent?) async throws -> String? {
        return try await withCheckedThrowingContinuation {continuation in
            self.sendTextMessage(text, formattedText: formattedText, localEcho: &localEcho, completion: {resp in
                switch resp {
                case let .success(v):
                    continuation.resume(returning: v)
                case let .failure(e):
                    continuation.resume(throwing: e)
                @unknown default:
                    continuation.resume(throwing: NioUnknownContinuationSwitchError(value: resp))
                }
            })
        }
    }
    
    @discardableResult
    func sendImage(data: Data, size: CGSize, mimeType: String, thumbnail: MXImage? = nil, localEcho: inout MXEvent?) async throws -> String? {
        return try await withCheckedThrowingContinuation {continuation in
            self.sendImage(data: data, size: size, mimeType: mimeType, thumbnail: thumbnail, localEcho: &localEcho, completion: {resp in
                switch resp {
                case let .success(v):
                    continuation.resume(returning: v)
                case let .failure(e):
                    continuation.resume(throwing: e)
                @unknown default:
                    continuation.resume(throwing: NioUnknownContinuationSwitchError(value: resp))
                }
            })
        }
    }
    
    @discardableResult
    func sendEvent(_ eventType: MXEventType, content: [String: Any], localEcho: inout MXEvent?) async throws -> String? {
        return try await withCheckedThrowingContinuation { continuation in
            self.sendEvent(eventType, content: content, localEcho: &localEcho, completion: { resp in
                switch resp {
                case let .success(v):
                    continuation.resume(returning: v)
                case let .failure(e):
                    continuation.resume(throwing: e)
                @unknown default:
                    continuation.resume(throwing: NioUnknownContinuationSwitchError(value: resp))
                }
            })
        }
    }
}
