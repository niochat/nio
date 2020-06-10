import SwiftUI
import NioKit
import UIKit

struct ShareContentView: View {
    @State var parentView: ShareNavigationController

    let rooms: [String: String]? = UserDefaults(suiteName: "group.stefan.chat.nio")?
        .dictionary(forKey: "users") as? [String: String]

    var cancelButton: some View {
        Button(action: {
            self.parentView.didSelectCancel()
        }, label: {
            Text("Cancel")
        })
    }

    var sendButton: some View {
        Button(action: {
            self.parentView.didSelectPost(roomID: "")
        }, label: {
            Text("Send")
        })
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(rooms!.keys.sorted(), id: \.self) { roomID in
                    Button(action: {
                        self.parentView.didSelectPost(roomID: roomID)
                    }, label: {
                        Text(self.rooms![roomID]!)
                    })
                }
            }
            .navigationBarTitle("Nio", displayMode: .inline)
            .navigationBarItems(trailing: cancelButton)
        }
    }
}
