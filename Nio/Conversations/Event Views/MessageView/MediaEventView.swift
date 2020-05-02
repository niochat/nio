import SwiftUI
import class SwiftMatrixSDK.MXEvent
import SDWebImageSwiftUI

struct MediaEventView: View {
    @Environment(\.userId) var userId
    @Environment(\.homeserver) var homeserver

    struct ViewModel {
        let mediaURLs: [MXURL]
        let sender: String
        let showSender: Bool
        let timestamp: String

        init(mediaURLs: [String],
             sender: String,
             showSender: Bool,
             timestamp: String) {
            self.mediaURLs = mediaURLs.compactMap(MXURL.init)
            self.sender = sender
            self.showSender = showSender
            self.timestamp = timestamp
        }

        init(event: MXEvent, showSender: Bool) {
            self.mediaURLs = event
                .getMediaURLs()
                .compactMap(MXURL.init)
            self.sender = event.sender ?? ""
            self.timestamp = Formatter.string(for: event.timestamp, timeStyle: .short)
            self.showSender = showSender
        }
    }

    let model: ViewModel

    var urls: [URL] {
        model.mediaURLs.compactMap { mediaURL in
            mediaURL.contentURL(on: self.homeserver)
        }
    }

    var isMe: Bool {
        model.sender == userId
    }

    var timestampView: some View {
        Text(model.timestamp)
        .font(.caption)
    }

    var senderView: some View {
        if model.showSender && !isMe {
            return AnyView(
                Text(model.sender)
                    .font(.caption)
            )
        } else {
            return AnyView(EmptyView())
        }
    }

    var body: some View {
        VStack(alignment: self.isMe ? .trailing : .leading, spacing: 5) {
            self.senderView
            WebImage(url: self.urls.first!, isAnimating: .constant(true))
                .resizable()
                .indicator(.activity)
                .scaledToFit()
                .mask(RoundedRectangle(cornerRadius: 15))
            self.timestampView
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.75,
               maxHeight: UIScreen.main.bounds.height * 0.75)
    }
}

//struct MediaEventView_Previews: PreviewProvider {
//    static var previews: some View {
//        MediaEventView(model: .init(mediaURLs: [], timestamp: <#String#>))
//    }
//}
