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
