import SwiftUI
import class MatrixSDK.MXEvent
import SDWebImageSwiftUI
import BlurHash

struct MediaEventView: View {
    @Environment(\.userId) var userId
    @Environment(\.homeserver) var homeserver

    struct ViewModel {
        let mediaURLs: [MXURL]
        let sender: String
        let showSender: Bool
        let timestamp: String
        var size: CGSize?
        var blurhash: String?

        init(mediaURLs: [String],
             sender: String,
             showSender: Bool,
             timestamp: String,
             size: CGSize?,
             blurhash: String?) {
            self.mediaURLs = mediaURLs.compactMap(MXURL.init)
            self.sender = sender
            self.showSender = showSender
            self.timestamp = timestamp
            self.size = size
            self.blurhash = blurhash
        }

        init(event: MXEvent, showSender: Bool) {
            self.mediaURLs = event
                .getMediaURLs()
                .compactMap(MXURL.init)
            self.sender = event.sender ?? ""
            self.timestamp = Formatter.string(for: event.timestamp, timeStyle: .short)
            self.showSender = showSender

            if let info: [String: Any] = event.content(valueFor: "info") {
                if let width = info["w"] as? Double,
                    let height = info["h"] as? Double {
                    self.size = CGSize(width: width, height: height)
                }
                if let blurhash = info["xyz.amorgan.blurhash"] as? String {
                    self.blurhash = blurhash
                }
            }
        }
    }

    let model: ViewModel

    var placeholder: UIImage {
        guard
            let size = model.size,
            let blurhash = model.blurhash,
            let img = UIImage(blurHash: blurhash, size: size)
        else { return UIImage() }
        return img
    }

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
                .placeholder(Image(uiImage: self.placeholder))
                .indicator(.activity)
                .scaledToFit()
                .mask(RoundedRectangle(cornerRadius: 15))
            self.timestampView
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.75,
               maxHeight: UIScreen.main.bounds.height * 0.75)
    }
}
