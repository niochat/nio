//
//  UXKit.swift
//  Nio
//
//  Created by Helge Heß on 05.03.21.
//  Copyright © 2021 Kilian Koeltzsch. All rights reserved.
//

#if os(macOS)
    import AppKit

    public typealias UXColor      = NSColor
    public typealias UXImage      = NSImage
    public typealias UXEdgeInsets = NSEdgeInsets
    public typealias UXFont       = NSFont

    public enum UXFakeTraitCollection {
        case current
    }

    public extension NSColor {
      
        @inlinable
        func resolvedColor(with fakeTraitCollection: UXFakeTraitCollection)
             -> UXColor
        {
            return self
        }
    }

  #if canImport(SwiftUI)
    import SwiftUI
    
    public enum UXFakeDisplayMode {
        case inline, automatic, large
    }
    public enum UXFakeAutocapitalizationMode {
        case none
    }

    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    public extension View {
      
        @inlinable
        func navigationBarTitle<S: StringProtocol>(
            _ title: S, displayMode: UXFakeDisplayMode = .inline
        ) -> some View
        {
            self.navigationTitle(title)
        }
      
        @inlinable
        func autocapitalization(_ mode: UXFakeAutocapitalizationMode) -> Self {
            return self
        }
    }
  #endif
#elseif canImport(UIKit)
    import UIKit

    public typealias UXColor      = UIColor
    public typealias UXImage      = UIImage
    public typealias UXEdgeInsets = UIEdgeInsets
    public typealias UXFont       = UIFont

  #if canImport(SwiftUI)
    import SwiftUI
  
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    public extension View {
    }
  #endif
#else
    #error("GNUstep not yet supported, sorry!")
#endif
