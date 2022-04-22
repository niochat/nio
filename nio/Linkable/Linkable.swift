//
//  File.swift
//  Nio
//
//  Created by Finn Behrens on 22.04.22.
//

import Foundation
import MatrixClient
import SwiftUI

@MainActor
class DeepLinker: ObservableObject {
    // FIXME: revert to nil for prod
    @Published var mainSelection: MainSelector? = .preferences

    @Published var preferenceSelection: PreferenceSelector?
}

extension DeepLinker {
    /// Selector for the main view.
    enum MainSelector: Hashable, Equatable {
        case all
        case favourites

        case home(MatrixFullUserIdentifier)
        case space(MatrixFullUserIdentifier, String)

        case preferences
    }

    /// Selector for a view inside the Preference section.
    enum PreferenceSelector: Hashable, Equatable {
        case account(MatrixFullUserIdentifier)
        case newAccount

        case icon
        case acknow
    }
}
