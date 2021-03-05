//
//  UXKit.swift
//  Nio
//
//  Created by Helge Heß on 05.03.21.
//  Copyright © 2021 Kilian Koeltzsch. All rights reserved.
//

#if os(macOS)
    import AppKit

    public typealias UXImage = NSImage
#elseif canImport(UIKit)
    import UIKit

    public typealias UXImage = UIImage
#else
    #error("GNUstep not yet supported, sorry!")
#endif
