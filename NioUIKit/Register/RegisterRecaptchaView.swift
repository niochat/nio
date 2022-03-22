//
//  RegisterRecaptchaView.swift
//  NioUIKit_iOS
//
//  Created by Finn Behrens on 22.03.22.
//

import AnyCodable
import os.log
import SwiftUI
import WebKit

struct RegisterRecaptchaView: View {
    var logger = Logger(subsystem: "\(Bundle.main.bundleIdentifier!).register.recaptcha", category: "register")

    var serverUrl: String
    var publicKey: String?
    var callback: (String) -> Void

    init(serverUrl _: String, parameters params: AnyCodable?, callback: @escaping ((String) -> Void)) {
        if let params = params,
           let params = params.value as? [String: Any],
           let publicKey = params["public_key"] as? String
        {
            logger.debug("public key: \(publicKey)")
            self.publicKey = publicKey
        }

        serverUrl = "https://matrix.org/" // serverUrl
        self.callback = callback
    }

    var body: some View {
        if let publicKey = publicKey {
            // TODO: nil
            RegisterRecaptchaWebView(url: URL(string: serverUrl), sitekey: publicKey, callback: callback, logger: logger)
        } else {
            Text("Did not find public key")
        }
    }
}

struct RegisterRecaptchaWebView: UIViewRepresentable {
    var url: URL?
    var sitekey: String
    var callback: (String) -> Void
    var logger: Logger

    func makeCoordinator() -> RegisterRecaptchaWebView.Coordinatior {
        RegisterRecaptchaWebView.Coordinatior(self)
    }

    func makeUIView(context _: Context) -> WKWebView {
        let view = WKWebView()
        return WKWebView()
    }

    func updateUIView(_ webView: UIViewType, context: Context) {
        let html = """
        <html>
        <head>
        <meta name='viewport' content='initial-scale=1.0' />
        <script type="text/javascript">
        var verifyCallback = function(response) {
            /* Generic method to make a bridge between JS and the WKWebView */
            var iframe = document.createElement('iframe');
            iframe.setAttribute('src', 'js:' + JSON.stringify({'action': 'verifyCallback', 'response': response}));
            document.documentElement.appendChild(iframe);
            iframe.parentNode.removeChild(iframe);
            iframe = null;
        };
        var onloadCallback = function() {
          grecaptcha.render('recaptcha_widget', {
            'sitekey' : "\(sitekey)",
            'callback': verifyCallback
          });
        };

        </script>
        </head>
        <body>
          <div id="recaptcha_widget"></div>
          <script src="https://www.google.com/recaptcha/api.js?onload=onloadCallback&render=explicit" async defer></script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: url)
        webView.navigationDelegate = context.coordinator
    }

    class Coordinatior: NSObject, WKNavigationDelegate {
        let parent: RegisterRecaptchaWebView

        init(_ parent: RegisterRecaptchaWebView) {
            self.parent = parent
        }

        func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let urlString = navigationAction.request.url?.absoluteString else {
                return .cancel
            }

            if urlString.hasPrefix("js:") {
                let decoder = JSONDecoder()

                guard let jsonString = urlString.components(separatedBy: "js:").last?.removingPercentEncoding,
                      let response = try? decoder.decode(CallbackResponse.self, from: Data(jsonString.utf8)),
                      response.action == "verifyCallback"
                else {
                    parent.logger.warning("Could not get json response")
                    return .cancel
                }

                parent.callback(response.response)

                return .cancel
            }

            return .allow
        }

        struct CallbackResponse: Decodable {
            var action: String
            var response: String
        }
    }
}

struct RegisterRecaptchaView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterRecaptchaView(serverUrl: "", parameters: nil, callback: { _ in })
    }
}
