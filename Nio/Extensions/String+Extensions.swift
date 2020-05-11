//
//  String+Extension.swift
//  Nio
//
//  Created by Vincent Esche on 5/13/20.
//  Copyright © 2020 Kilian Koeltzsch. All rights reserved.
//

import Foundation

// FIXME: this seems like it could back-fire,
// encouraging the use of stringly-typed code.
extension String: Identifiable {
    public var id: String {
        self
    }
}
