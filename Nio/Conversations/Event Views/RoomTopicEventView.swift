import SwiftUI
import class SwiftMatrixSDK.MXEvent

struct RoomTopicEventView: View {
    struct ViewModel {
        let sender: String
        let topic: String

        init(sender: String, topic: String) {
            self.sender = sender
            self.topic = topic
        }

        init(event: MXEvent) {
            self.init(sender: event.sender ?? "unknown",
                      topic: event.content(valueFor: "topic") ?? "unknown")
        }
    }

    let model: ViewModel

    var body: some View {
        GenericEventView(text: "\(model.sender) changed the topic to \(model.topic)")
    }
}

struct RoomTopicEventView_Previews: PreviewProvider {
    static var previews: some View {
        RoomTopicEventView(model: .init(sender: "Jane Doe", topic: "The Orville"))
    }
}
