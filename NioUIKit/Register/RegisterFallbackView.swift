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

    var body: some View {
        VStack {
            Text("Login fallback: \(flow.rawValue)")
        }
    }
}

struct RegisterFallbackView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterFallbackView(session: nil, flow: "dev.matrixcore.fallback-flow", apiUrl: URL(string: "example.com")!)
    }
}
