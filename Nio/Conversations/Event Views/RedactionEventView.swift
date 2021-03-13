import SwiftUI

struct RedactionEventView: View {
    struct ViewModel {
        let sender: String
        let redactor: String
        let reason: String?
    }

    let model: ViewModel

    private var redactionText: String {
        if model.sender == model.redactor {
            return "🗑 \(L10n.Event.Redaction.redactSelf(model.redactor))"
        }
        return "🗑 \(L10n.Event.Redaction.redactOther(model.redactor, model.sender))"
    }

    var body: some View {
        HStack {
            Spacer()
            VStack {
                Text(redactionText)
                    .font(.caption)
                    .foregroundColor(.gray)
                if model.reason != nil {
                    Text(verbatim: L10n.Event.reason(model.reason!))
                        .foregroundColor(.gray)
                        .font(.callout)
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
            RedactionEventView(model: .init(sender: "Jane Doe",
                                            redactor: "Jane Doe",
                                            reason: nil))
                .previewDisplayName("self redact")
            RedactionEventView(model: .init(sender: "John Doe",
                                            redactor: "Jane Doe",
                                            reason: nil))
                .previewDisplayName("redact other")
            RedactionEventView(model: .init(sender: "Jane Doe",
                                            redactor: "Jane Doe",
                                            reason: "Totally valid reason with longer text"))
                .previewDisplayName("self redact with reason")

            VStack(spacing: 0) {
                RedactionEventView(model: .init(sender: "Jane Doe",
                                                redactor: "Jane Doe",
                                                reason: nil))
                RedactionEventView(model: .init(sender: "Jane Doe",
                                                redactor: "Jane Doe",
                                                reason: "some reason"))
                RedactionEventView(model: .init(sender: "John Doe",
                                                redactor: "Jane Doe",
                                                reason: "spam spam spam"))
            }
            .previewDisplayName("spacing")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
