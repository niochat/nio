import SwiftUI

struct AppIcon: Identifiable, View {
    static var alternateIcons = [
        AppIcon(title: "Default"),
        AppIcon(title: "Six Colors Dark"),
        AppIcon(title: "Six Colors Light"),
        AppIcon(title: "Sketch"),
    ]

    let title: String
    let attribution: String?

    var id: String {
        title
    }

    var previewName: String {
        "App Icons/\(title)"
    }

    init(title: String, attribution: String? = nil) {
        self.title = title
        self.attribution = attribution
    }

    var body: some View {
        HStack {
            Image(previewName)
                .resizable()
                .frame(width: 60, height: 60)
                .cornerRadius(12)
                .padding(5)
            VStack(alignment: .leading) {
                Text(title)
                if attribution != nil {
                    Text(attribution!)
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

class AppIconTitle: ObservableObject {
    var current: String {
        get {
            UIApplication.shared.alternateIconName ?? "Default"
        }
        set {
            var iconName: String? = newValue
            if iconName == "Default" {
                iconName = nil
            }
            objectWillChange.send()
            UIApplication.shared.setAlternateIconName(iconName) { error in
                guard let error = error else { return }
                print("Error setting new app icon: \(error)")
            }
        }
    }
}
