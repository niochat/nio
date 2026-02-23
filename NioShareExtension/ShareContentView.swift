import SwiftUI
import NioKit
import UIKit

@available(iOSApplicationExtension 14.0, *)
struct ShareContentView: View {
    @State var parentView: ShareNavigationController
    @State var showConfirm = false
    @State var selectedRoom: RoomItem?

    var rooms: [RoomItem]?

    public init(parentView: ShareNavigationController) {
        _parentView = State(initialValue: parentView)
        let data = UserDefaults.group.data(forKey: "roomList")!
        do {
            let decoder = JSONDecoder()
            let temp = try decoder.decode([RoomItem].self, from: data)
            self.rooms = temp
            self.rooms?.sort(by: { $0.messageDate > $1.messageDate })
        } catch {
            print("An error occured: \(error)")
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                List(rooms!, id: \.self) { room in
                    Button(action: {
                        self.selectedRoom = room
                        self.showConfirm.toggle()
                    }, label: {
                        Text(room.displayName)
                    })
                }
                .padding(.bottom, 20.0)
                .listStyle(GroupedListStyle())
                .navigationBarTitle("Nio")
                .alert(isPresented: $showConfirm) {
                    Alert(
                        title: Text("Send to " + self.selectedRoom!.displayName),
                        primaryButton: .default(
                            Text("Send"),
                            action: {
                                self.parentView.didSelectPost(roomID: self.selectedRoom!.roomId)
                        }),
                        secondaryButton: .cancel())
                }
                // This is ugly, but otherwise the last results are too far down. Update if you know
                // a better way.
                Text("")
                Text("")
                Text("")
            }
        }
    }
}

struct ShareContentView_Previews: PreviewProvider {
    static var previews: some View {
        /*@START_MENU_TOKEN@*/Text("Hello, World!")/*@END_MENU_TOKEN@*/
    }
}
