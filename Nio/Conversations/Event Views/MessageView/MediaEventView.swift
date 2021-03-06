import SwiftUI
import class MatrixSDK.MXEvent
import SDWebImageSwiftUI
import BlurHash

struct MediaEventView: View {
    @Environment(\.userId) private var userId
    @Environment(\.homeserver) private var homeserver

    struct ViewModel {
        fileprivate let mediaURLs: [MXURL]
        fileprivate let sender: String
        fileprivate let showSender: Bool
        fileprivate let timestamp: String
        fileprivate var size: CGSize?
        fileprivate var blurhash: String?

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
                self.blurhash = info["xyz.amorgan.blurhash"] as? String
            }
        }
    }

    let model: ViewModel
    let contextMenuModel: EventContextMenuModel

    @ViewBuilder
    var placeholder: some View {
        if let size = model.size,
           let blurhash = model.blurhash,
           let img = UIImage(blurHash: blurhash, size: size) {
            Image(uiImage: img)
        } else {
            Rectangle()
                .foregroundColor(Color.borderedMessageBackground)
        }
    }

    var urls: [URL] {
        model.mediaURLs.compactMap { mediaURL in
            mediaURL.contentURL(on: self.homeserver)
        }
    }

    private var isMe: Bool {
        model.sender == userId
    }

    private var timestampView: some View {
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
        VStack(alignment: isMe ? .trailing : .leading, spacing: 5) {
            senderView
            WebImage(url: urls.first, isAnimating: .constant(true))
                .resizable()
                .placeholder { placeholder }
                .indicator(.activity)
                .aspectRatio(model.size ?? CGSize(width: 3, height: 2), contentMode: .fit)
                .mask(RoundedRectangle(cornerRadius: 15))
            timestampView
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.75,
               maxHeight: UIScreen.main.bounds.height * 0.75)
        .contextMenu(ContextMenu(menuItems: {
            EventContextMenu(model: contextMenuModel)
        }))
    }
}

struct MediaEventView_Previews: PreviewProvider {
    static var previews: some View {
        let sendingModel = MediaEventView.ViewModel(
            mediaURLs: [],
            sender: "",
            showSender: false,
            timestamp: "9:41 am",
            size: CGSize(width: 3000, height: 2000),
            blurhash: nil)
        MediaEventView(model: sendingModel, contextMenuModel: .previewModel)
    }
}
