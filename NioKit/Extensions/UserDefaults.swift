//
//  UserDefaults.swift
//  NioKit
//
//  Created by Stefan Hofman on 05/09/2020.
//  Copyright © 2020 Kilian Koeltzsch. All rights reserved.
//

import Foundation

public extension UserDefaults {
    static let group = UserDefaults(suiteName: "group." + (Bundle.main.infoDictionary?["AppGroup"] as? String)!)!
}
