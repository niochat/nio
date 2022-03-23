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

    init(serverUrl: String, parameters params: AnyCodable?, callback: @escaping ((String) -> Void)) {
        if let params = params,
           let params = params.value as? [String: Any],
           let publicKey = params["public_key"] as? String
        {
            logger.debug("public key: \(publicKey)")
            self.publicKey = publicKey
        }

        self.serverUrl = serverUrl
        self.callback = callback
    }

    var html: String {
        """
        <html>
        <head>
        <meta name='viewport' content='initial-scale=1.0' />
        <script type="text/javascript">
        var onloadCallback = function() {
          grecaptcha.render('recaptcha_widget', {
            'sitekey' : "\(publicKey ?? "")",
            'callback': window.recaptchaCallback
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
    }

    var body: some View {
        if publicKey != nil {
            RegisterWebView(url: URL(string: serverUrl), html: html, callback: { response in
                guard let response = response,
                      response.action == "verifyCallback",
                      let response = response.response
                else {
                    logger.warning("Could not get json response from WebView")
                    return
                }

                callback(response)
            })
        } else {
            VStack {
                Text("Did not find public key")
                    .bold()
                    .padding()

                Text("Please contact your homeserver administrator")
            }
        }
    }
}

struct RegisterRecaptchaView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterRecaptchaView(serverUrl: "", parameters: nil, callback: { _ in })
    }
}
