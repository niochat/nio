import SwiftUI
import class MatrixSDK.MXEvent

struct RoomTopicEventView: View {
    struct ViewModel {
        let sender: String
        let topic: String

        init(sender: String, topic: String) {
            self.sender = sender
            self.topic = topic
        }

        init(event: MXEvent) {
            self.init(sender: event.sender ?? L10n.Event.unknownSenderFallback,
                      topic: event.content(valueFor: "topic") ?? "")
        }
    }

    let model: ViewModel

    var body: some View {
        GenericEventView(text: L10n.Event.RoomTopic.change(model.sender, model.topic))
    }
}

struct RoomTopicEventView_Previews: PreviewProvider {
    static var previews: some View {
        RoomTopicEventView(model: .init(sender: "Jane Doe", topic: "The Orville"))
    }
}
