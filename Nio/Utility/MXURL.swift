import Foundation
import SwiftMatrixSDK

struct MXURL {
    var mxContentURI: URL

    init?(mxContentURI: String) {
        guard let uri = URL(string: mxContentURI) else {
            return nil
        }
        self.mxContentURI = uri
    }

    var contentURL: URL? {
        guard let homeserver = URL(string: MatrixServices.shared.client?.homeserver ?? "") else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = homeserver.host
        guard let contentHost = mxContentURI.host else { return nil }
        components.path = "/_matrix/media/r0/download/\(contentHost)/\(mxContentURI.lastPathComponent)"
        return components.url
    }

    static var nioIcon: MXURL {
        MXURL(mxContentURI: "mxc://matrix.org/rdElwkPTTrdZljUuKwkSEMqV")!
    }
}
