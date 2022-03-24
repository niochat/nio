//
//  NioUIKit.swift
//  Nio
//
//  Created by Finn Behrens on 24.03.22.
//

import Foundation
import SwiftUI

struct NioUIKitDebugModeKey: EnvironmentKey {
    static var defaultValue: Bool = false
}

public extension EnvironmentValues {
    var nioUIKitDebugMode: Bool {
        get { self[NioUIKitDebugModeKey.self] }
        set { self[NioUIKitDebugModeKey.self] = newValue }
    }
}
