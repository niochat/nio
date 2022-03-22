//
//  RegisterServerChooser.swift
//  NioUIKit_iOS
//
//  Created by Finn Behrens on 22.03.22.
//

import SwiftUI

/* struct RegisterServerChooser: View {

     @Binding var currentState: RegisterContainer.CurrentState
     @Binding var currentServer: String

     var body: some View {
         if currentState == .login {
             Button(currentServer) {
                 currentState = .server
             }
         } else if currentState == .server {
             Text(currentServer)
         } else {
             ProgressView()
         }
     }
 }
 */
/* struct RegisterServerChooser: View {
     @State var currentServer: String = "matrix.org"

     @State var showSheet: Bool = false

     @State var selection: Server = .matrix_org
     @State var serverUrl: String = ""
     @State var working: Bool = false

     var body: some View {
         Button(currentServer) {
             showSheet = true
         }.sheet(isPresented: $showSheet) {
             Sheet()
         }
     }

     struct Sheet: View {
         @Environment(\.dismiss) var dismiss

         var body: some View {
             Text("foobar")
         }
     }

     enum Server: CaseIterable, Hashable, Identifiable {
         var id: String {
             return self.name
         }

         var name: String {
             switch self {
             case .matrix_org:
                 return "matrix.org"
             case .other:
                 return "Other Homeserver"
             }
         }

         var isOther: Bool {
             return self == .other
         }

         case matrix_org
         case other
     }
 }

 /* struct RegisterServerChooserSheet: View {

     var currentServer: String {
         if selection.isOther {
             return serverUrl
         } else {
             return selection.name
         }
     }

     var body: some View {
         VStack {
             HStack {
                 Button(role: .cancel, action: {
                     working = false
                     dismiss()
                 }, label: {
                     Text("Cancel")
                 })
                 Spacer(minLength: 0)
                 Button("Ok") {
                     print("using server: \(currentServer)")
                     working = true

                     dismiss()
                 }.onChange(of: working, perform: { newValue in
                     if newValue == false {
                         dismiss()
                     }
                 })
             }
             .padding()

             Spacer(minLength: 0)

             if !working {
                 Text("Decide where your account is hosted")
                     .bold()

                 Text("We call the places where you can host your account 'homeservers'. Matrix.org is the biggest public homeserver in the world, so it's a good place for many.").fontWeight(.light)

                 Picker(selection: $selection, label: Text("foobar")) {
                     ForEach(Server.allCases) { server in
                         Text(server.name).tag(server)
                     }
                 }

                 if selection.isOther {
                     TextField("Other Homeserver", text: $serverUrl)
                         .keyboardType(.URL)
                         .textContentType(.URL)
                         .textInputAutocapitalization(.never)
                         .disableAutocorrection(true)
                 }
             }

             Spacer(minLength: 0)
         }
     }

 } */
  */

struct RegisterServerChooser_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            /* RegisterServerChooser(currentState: .constant(.login), currentServer: .constant("matrix.org"))
             .previewDisplayName("login") */

            /* RegisterServerChooser(currentState: .constant(.server), currentServer: .constant("matrix.org"))
             .previewDisplayName("server") */
            // currentServer: .constant(.matrix_org))
        }
    }
}
