//
//  RegisterWebView.swift
//  NioUIKit_iOS
//
//  Created by Finn Behrens on 22.03.22.
//

import SwiftUI
import WebKit

struct RegisterWebView: UIViewRepresentable {
    var url: URL?
    var html: String
    var callback: (CallbackResponse?) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()

        view.navigationDelegate = context.coordinator

        return view
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        uiView.loadHTMLString(html, baseURL: url)
        uiView.navigationDelegate = context.coordinator
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: RegisterWebView

        init(_ parent: RegisterWebView) {
            self.parent = parent
        }

        func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let urlString = navigationAction.request.url?.absoluteString else {
                return .cancel
            }

            if urlString.hasPrefix("js:") {
                let decoder = JSONDecoder()

                guard let jsonString = urlString.components(separatedBy: "js:").last?.removingPercentEncoding,
                      let response = try? decoder.decode(CallbackResponse.self, from: Data(jsonString.utf8))
                else {
                    parent.callback(nil)
                    return .cancel
                }

                parent.callback(response)

                return .cancel
            }

            return .allow
        }
    }

    struct CallbackResponse: Decodable {
        var action: String
        var response: String
    }
}

struct RegisterWebView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // RegisterWebView()
        }
    }
}
