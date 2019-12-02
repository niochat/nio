import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: MatrixStore<AppState, AppAction>

    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: {
                        self.store.send(SideEffect.logout)
                    }, label: {
                        Text("Log Out")
                    })
                }
            }
            .listStyle(GroupedListStyle())
            .navigationBarTitle("Settings", displayMode: .inline)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
