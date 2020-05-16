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

    static var alternateIcons = [
        AppIcon(title: "Default"),
        AppIcon(title: "Sketch"),
    ]

    var appIcon: String {
        get {
            UIApplication.shared.alternateIconName ?? "Default"
        }
        set {
            var iconName: String? = newValue
            if iconName == "Default" {
                iconName = nil
            }
            UIApplication.shared.setAlternateIconName(iconName) { error in
                guard let error = error else { return }
                print("Error setting new app icon: \(error)")
            }
        }
    }
}
