//
//  UserDefaults.swift
//  NioKit
//
//  Created by Stefan Hofman on 05/09/2020.
//  Copyright © 2020 Kilian Koeltzsch. All rights reserved.
//

import Foundation

public extension UserDefaults {
    private static let appGroup = Bundle.main.infoDictionary?["AppGroup"] as! String
  #if os(macOS)
    private static let teamIdentifierPrefix = Bundle.main
      .object(forInfoDictionaryKey: "TeamIdentifierPrefix") as? String ?? ""

    static let suiteName = teamIdentifierPrefix + appGroup
  #else // iOS
    static let suiteName = "group." + appGroup
  #endif
  
    static let group = UserDefaults(suiteName: suiteName)!
}
