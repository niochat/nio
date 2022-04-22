//
//  File.swift
//  Nio
//
//  Created by Finn Behrens on 22.04.22.
//

import Foundation
import SwiftUI
import MatrixClient

@MainActor
class DeepLinker: ObservableObject {

    @Published var mainSelection: MainSelector?

    @Published var preferenceSelector: PreferenceSelector?
}

extension DeepLinker {
    /// Selector for the main view.
    enum MainSelector: Hashable, Equatable {
        case preferences
        case home(MatrixFullUserIdentifier)
        case space(MatrixFullUserIdentifier, String)
    }

    /// Selector for a view inside the Preference section.
    enum PreferenceSelector: Hashable, Equatable {
        case account(MatrixFullUserIdentifier)
    }
}

