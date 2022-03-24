//
//  RegisterEmailView.swift
//  NioUIKit_iOS
//
//  Created by Finn Behrens on 22.03.22.
//

import SwiftUI

struct RegisterEmailView: View {
    let resend: () -> Void
    let retry: () -> Void
    @State var email: String

    var body: some View {
        VStack {
            Text("Verify Email")
                .bold()
                .padding()

            HStack {
                Text("email:")
                Spacer(minLength: 0)
                Text(email)
            }

            HStack {
                Button("Resend", role: .destructive) {
                    resend()
                }

                Spacer(minLength: 0)

                Button("Retry") {
                    retry()
                }
            }
        }
        // TODO: retry every 15 seconds, but cancel when view goes out of scope
    }
}

struct RegisterEmailView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterEmailView(resend: {}, retry: {}, email: "mail@example.com")
    }
}
