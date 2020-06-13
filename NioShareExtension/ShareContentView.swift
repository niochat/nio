import SwiftUI
import NioKit
import UIKit

struct ShareContentView: View {
    @State var parentView: ShareNavigationController
    @State var showConfirm = false
    @State var selectedRoom: String?
    @State var selectedID: String?

    let rooms: [String: String]? = UserDefaults(suiteName: "group." + ((Bundle.main.infoDictionary?["AppGroup"] as? String) ?? ""))?
        .dictionary(forKey: "users") as? [String: String]

    var cancelButton: some View {
        Button(action: {
            self.parentView.didSelectCancel()
        }, label: {
            Text("Cancel")
        })
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(rooms!.keys.sorted(), id: \.self) { roomID in
                    Button(action: {
                        self.selectedRoom = self.rooms![roomID]!
                        self.selectedID = roomID
                        self.showConfirm.toggle()
                    }, label: {
                        Text(self.rooms![roomID]!)
                    })
                }
            }
            .navigationBarTitle("Nio", displayMode: .inline)
            .navigationBarItems(trailing: cancelButton)
            .alert(isPresented: $showConfirm) {
                Alert(
                    title: Text("Send to " + (self.selectedRoom ?? "")),
                    primaryButton: .default(
                        Text("Send"),
                        action: {
                            self.parentView.didSelectPost(roomID: self.selectedID!)
                    }),
                secondaryButton: .cancel())
            }
        }
    }
}
