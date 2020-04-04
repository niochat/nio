import SwiftUI

struct RedactionEventView: View {
    struct ViewModel {
        let sender: String
        let reason: String?
    }

    var model: ViewModel

    var body: some View {
        HStack {
            Spacer()
            VStack {
                Text("🗑 \(model.sender) removed message.")
                    .font(.caption)
                    .foregroundColor(.gray)
                if model.reason != nil {
                    Text("\(model.reason!)")
                        .foregroundColor(.gray)
                }
            }
            Spacer()
        }
        .padding(.vertical, 3)
    }
}

struct RedactionView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RedactionEventView(model: .init(sender: "Jane Doe", reason: nil))
            RedactionEventView(model: .init(sender: "Jane Doe", reason: "Totally valid reason with longer text"))
            VStack(spacing: 0) {
                RedactionEventView(model: .init(sender: "Jane Doe", reason: nil))
                RedactionEventView(model: .init(sender: "Jane Doe", reason: "some reason"))
                RedactionEventView(model: .init(sender: "Jane Doe", reason: nil))
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
