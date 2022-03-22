//
//  RegisterTermsView.swift
//  NioUIKit_iOS
//
//  Created by Finn Behrens on 22.03.22.
//

import AnyCodable
import SwiftUI

struct RegisterTermsView: View {
    @State var todo: [String]

    let policies: [String: Any]
    let callback: () -> Void

    init(parameters params: AnyCodable?, callback: @escaping (() -> Void)) {
        if let params = params,
           let params = params.value as? [String: Any],
           let policies = params["policies"] as? [String: Any]
        {
            self.policies = policies
            todo = Array(policies.keys)
            print(policies)
        } else {
            policies = [:]
            todo = []

            callback()
        }
        self.callback = callback
    }

    var body: some View {
        if let first = todo.last,
           let first = policies[first],
           let first = first as? [String: Any],
           let en = first["en"] as? [String: Any],
           let name = en["name"] as? String,
           let url = en["url"] as? String
        {
            VStack {
                Text(name)
                    .padding()
                RegisterWebView(url: URL(string: url), callback: { _ in })

                Button("Accept") {
                    _ = todo.popLast()
                    if todo.isEmpty {
                        callback()
                    }
                }
            }
        } else {
            Text("Error")
        }
    }
}

struct RegisterTermsView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterTermsView(parameters: nil, callback: {})
    }
}
