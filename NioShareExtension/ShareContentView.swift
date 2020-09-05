import SwiftUI
import NioKit
import UIKit

struct ShareContentView: View {
    @State var parentView: ShareNavigationController
    @State var showConfirm = false
    @State var selectedRoom: String?
    @State var selectedID: String?

    let rooms: [String: String]? = UserDefaults.group.dictionary(forKey: "roomList") as? [String: String]

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
                        self.selectedID = roomID
                        self.showConfirm.toggle()
                    }, label: {
                        Text(self.rooms![roomID]!)
                    })
                }
            }
            .listStyle(GroupedListStyle())
            .navigationBarTitle("Nio", displayMode: .inline)
            .navigationBarItems(trailing: cancelButton)
            .alert(isPresented: $showConfirm) {
                Alert(
                    title: Text("Send to " + (self.rooms![self.selectedID ?? ""]! )),
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

struct ShareContentView_Previews: PreviewProvider {
    static var previews: some View {
        /*@START_MENU_TOKEN@*/Text("Hello, World!")/*@END_MENU_TOKEN@*/
    }
}
