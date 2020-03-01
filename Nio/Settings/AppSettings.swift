import Foundation
import SwiftUI
import Combine

class AppSettings: ObservableObject {
    var accentColor: Color {
        get {
            guard
                let stored = UserDefaults.standard.string(forKey: #function),
                let color = Color(description: stored)
            else { return .purple }
            return color
        }
        set {
            UserDefaults.standard.set(newValue.description, forKey: #function)
            objectWillChange.send()
        }
    }
}
