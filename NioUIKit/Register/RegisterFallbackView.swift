//
//  RegisterFallbackView.swift
//  Nio
//
//  Created by Finn Behrens on 23.03.22.
//

import MatrixClient
import SwiftUI

struct RegisterFallbackView: View {
    let session: String?
    let flow: MatrixLoginFlow
    let apiUrl: URL
    let callback: () -> Void

    init(session: String? = nil, flow: MatrixLoginFlow, apiUrl: URLComponents, callback: @escaping (() -> Void)) {
        self.session = session
        self.flow = flow
        self.callback = callback
        var apiUrl = apiUrl

        apiUrl.path = "/_matrix/client/v3/auth/\(flow.rawValue)/fallback/web"
        apiUrl.queryItems = [URLQueryItem(name: "session", value: session)]
        self.apiUrl = apiUrl.url!
    }

    var body: some View {
        VStack {
            Text("Web flow: \(flow.rawValue)")

            RegisterWebView(url: apiUrl) { response in
                guard response?.action == "onAuthDone" else {
                    fatalError("Not an onAuthDone action in RegisterFallbackView")
                }

                callback()
            }
        }
    }
}

struct RegisterFallbackView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            /* RegisterFallbackView(session: nil, flow: "dev.matrixcore.fallback-flow", apiUrl: URL(string: "example.com")!) */
        }
    }
}
