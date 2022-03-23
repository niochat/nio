//
//  RegisterWebView.swift
//  NioUIKit_iOS
//
//  Created by Finn Behrens on 22.03.22.
//

import SwiftUI
import WebKit

private let userScript = """
window.onAuthDone = function () {
    window.webkit.messageHandlers.finishView.postMessage(JSON.stringify({'action': 'onAuthDone'}));
}
window.recaptchaCallback = function (response) {
    window.webkit.messageHandlers.finishView.postMessage(JSON.stringify({'action': 'verifyCallback', 'response': response}));
}
"""

struct RegisterWebView {
    @State var url: URL?
    @State var html: String?
    @State var callback: (CallbackResponse?) -> Void

    func getConfig(context: Context) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()

        let userController = UserController()
        userController.add(context.coordinator as WKScriptMessageHandler, name: "finishView")
        userController.addUserScript(WKUserScript(source: userScript, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        config.userContentController = userController

        return config
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: RegisterWebView

        init(_ parent: RegisterWebView) {
            self.parent = parent
        }

        func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
            let decoder = JSONDecoder()
            guard let body = message.body as? String,
                  let response = try? decoder.decode(CallbackResponse.self, from: Data(body.utf8))
            else {
                parent.callback(nil)
                return
            }

            print(response)
            parent.callback(response)
        }
    }

    class UserController: WKUserContentController {}

    struct CallbackResponse: Decodable {
        var action: String
        var response: String?
    }
}

#if os(macOS)
    extension RegisterWebView: NSViewRepresentable {
        func makeNSView(context: Context) -> WKWebView {
            let view = WKWebView(frame: .zero, configuration: getConfig(context: context))

            view.navigationDelegate = context.coordinator

            return view
        }

        func updateNSView(_ nsView: WKWebView, context: Context) {
            if let html = html {
                nsView.loadHTMLString(html, baseURL: url)
            } else if let url = url {
                nsView.load(URLRequest(url: url))
            }
            nsView.navigationDelegate = context.coordinator
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
    }
#else
    extension RegisterWebView: UIViewRepresentable {
        func makeUIView(context: Context) -> WKWebView {
            let view = WKWebView(frame: .zero, configuration: getConfig(context: context))

            view.navigationDelegate = context.coordinator

            return view
        }

        func updateUIView(_ uiView: UIViewType, context: Context) {
            if let html = html {
                uiView.loadHTMLString(html, baseURL: url)
            } else if let url = url {
                uiView.load(URLRequest(url: url))
            }
            uiView.navigationDelegate = context.coordinator
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
    }
#endif

struct RegisterWebView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // RegisterWebView()
        }
    }
}
