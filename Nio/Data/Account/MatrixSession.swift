import Foundation
import Combine

import SwiftMatrixSDK

// Implementation heavily inspired by [Messagerie](https://github.com/manuroe/messagerie).

class MatrixSession {
    let matrixAccount: MatrixAccount
    let matrixRestClient: MXRestClient
    let session: MXSession

    private lazy var mediaManager: MXMediaManager = {
        MXMediaManager(homeServer: matrixAccount.homeserver.absoluteString)
    }()

    init(account: MatrixAccount) {
        self.matrixAccount = account

        let credentials = MXCredentials(homeServer: account.homeserver.absoluteString,
                                        userId: account.userId,
                                        accessToken: account.accessToken)
        credentials.deviceId = account.deviceId

        matrixRestClient = MXRestClient(credentials: credentials, unrecognizedCertificateHandler: nil)
        session = MXSession(matrixRestClient: matrixRestClient)
    }

    private func startSession() {
        let store = MXFileStore()
        session.setStore(store) { _ in
            self.session.crypto.warnOnUnknowDevices = false

            // store.deleteAllData()

            self.session.start { _ in }
        }
    }

    var sessionStateObserver: NSObjectProtocol?
    var dataReady: Future<MXSessionState, Never> {
        Future<MXSessionState, Never> { promise in
            if self.session.state.rawValue >= MXSessionStateStoreDataReady.rawValue {
                promise(.success(self.session.state))
                return
            }

            if self.session.store == nil && self.session.state == MXSessionStateInitialised {
                self.startSession()
            }

            self.sessionStateObserver = NotificationCenter.default
                .addObserver(forName: NSNotification.Name.mxSessionStateDidChange,
                             object: self.session,
                             queue: nil) { _ in
                                if self.session.state.rawValue >= MXSessionStateStoreDataReady.rawValue {
                                    promise(.success(self.session.state))
                                }
                             }
        }
    }

    func url(for mxcString: String,
             size: CGSize? = nil,
             method: MXThumbnailingMethod = MXThumbnailingMethodCrop) -> String? {

        var urlString: String?
        if let size = size {
            urlString = self.mediaManager.url(ofContentThumbnail: mxcString, toFitViewSize: size, with: method)
        } else {
            urlString = self.mediaManager.url(ofContent: mxcString)
        }

        return urlString
    }
}
