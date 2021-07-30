import SwiftUI
import class MatrixSDK.MXEvent
import class NioKit.AccountStore
import SDWebImageSwiftUI

#if os(macOS)
#else
  import BlurHash
#endif

struct MediaEventView: View {
    @Environment(\.userId) private var userId
    @Environment(\.homeserver) private var homeserver

    struct ViewModel {
        fileprivate let event: MXEvent?
        fileprivate let mediaURLs: [MXURL]
        fileprivate let sender: String
        fileprivate let showSender: Bool
        fileprivate let timestamp: String
        fileprivate var size: CGSize?
        fileprivate var blurhash: String?
        
        @State private var imageUrl: URL?

        init(mediaURLs: [String],
             sender: String,
             showSender: Bool,
             timestamp: String,
             size: CGSize?,
             blurhash: String?) {
            self.event = nil
            self.mediaURLs = mediaURLs.compactMap(MXURL.init)
            self.sender = sender
            self.showSender = showSender
            self.timestamp = timestamp
            self.size = size
            self.blurhash = blurhash
        }

        init(event: MXEvent, showSender: Bool) {
            self.event = event
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
    @MainActor
    var placeholder: some View {
        // TBD: isn't there a "placeholder" generator in SwiftUI now?
      #if os(macOS)
        Rectangle()
            .foregroundColor(Color.borderedMessageBackground)
      #else
        if let size = model.size,
           let blurhash = model.blurhash,
           let img = UIImage(blurHash: blurhash, size: size) {
            Image(uiImage: img)
        } else {
            Rectangle()
                .foregroundColor(Color.borderedMessageBackground)
        }
      #endif
    }

    var urls: [URL] {
        return model.mediaURLs.compactMap { mediaURL in
            mediaURL.contentURL(on: self.homeserver)
        }
    }
    @State private var encryptedUrl: String?
    var encrpytedUiImage: UIImage? {
        guard let encryptedUrl = encryptedUrl else {
            return nil
        }
        print("trying to load image: \(encryptedUrl)")
        return UIImage(contentsOfFile: encryptedUrl)
    }

    private var isMe: Bool {
        model.sender == userId
    }

    private var timestampView: some View {
        Text(model.timestamp)
        .font(.caption)
    }

    @ViewBuilder private var senderView: some View {
        if model.showSender && !isMe {
                Text(model.sender)
                    .font(.caption)
        }
    }

    var body: some View {
        VStack(alignment: isMe ? .trailing : .leading, spacing: 5) {
            senderView
            if let encrpytedUiImage = encrpytedUiImage {
                Image(uiImage: encrpytedUiImage)
            } else {
                WebImage(url: urls.first, isAnimating: .constant(true))
                                .resizable()
                                .placeholder { placeholder }
                                .indicator(.activity)
                                .aspectRatio(model.size ?? CGSize(width: 3, height: 2), contentMode: .fit)
                                .mask(RoundedRectangle(cornerRadius: 15))
                // TODO: use AsyncImage (currently not supporting gifs)
                /*AsyncImage(url: self.urls.first, content: {phase in
                    switch phase {
                    case .empty:
                        placeholder
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(model.size ?? CGSize(width: 3, height: 2), contentMode: .fit)
                            .mask(RoundedRectangle(cornerRadius: 15))
                    case .failure(let error):
                        Text("Error loading picture \(error.localizedDescription)")
                        
                    default:
                        placeholder
                            .onAppear(perform: {
                                print("This case to AsyncImage is unknown (new)")
                            })
                    }
                })*/
                    .accessibility(label: Text("Image \(urls.first?.absoluteString ?? "")"))
            }
            timestampView
        }
        .contextMenu(ContextMenu(menuItems: {
            EventContextMenu(model: contextMenuModel)
        }))
        #if os(iOS)
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75,
                   maxHeight: UIScreen.main.bounds.height * 0.75)
        #endif
            .task {
                guard let event = self.model.event else {
                    return
                }
                if event.isEncrypted {
                    self.encryptedUrl = await AccountStore.shared.downloadEncrpytedMedia(event: event)
                }
            }
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
