import SwiftUI

struct AppIcon: Identifiable, View {
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
    static var alternatives = [
        "Default",
        "Six Colors Dark",
        "Six Colors Light",
        "Sketch",
    ]

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
