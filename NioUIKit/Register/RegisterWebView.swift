//
//  RegisterWebView.swift
//  NioUIKit_iOS
//
//  Created by Finn Behrens on 22.03.22.
//

import SwiftUI
import WebKit

struct RegisterWebView {
    @State var url: URL?
    @State var html: String?
    @State var callback: (CallbackResponse?) -> Void

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

#if os(macOS)
    extension RegisterWebView: NSViewRepresentable {
        func makeNSView(context: Context) -> WKWebView {
            let view = WKWebView()

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
            let view = WKWebView()

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

/*
 struct RegisterWebView: UIViewRepresentable {
     @State var url: URL?
     @State var html: String?
     @State var callback: (CallbackResponse?) -> Void

     func makeUIView(context: Context) -> WKWebView {
         let view = WKWebView()

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
 }*/

struct RegisterWebView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // RegisterWebView()
        }
    }
}
