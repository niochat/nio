import Foundation
import SwiftUI
import Combine

class AppSettings: ObservableObject {
    static var alternateIcons = [
        AppIcon(title: "Default"),
        AppIcon(title: "Six Colors Dark"),
        AppIcon(title: "Six Colors Light"),
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
