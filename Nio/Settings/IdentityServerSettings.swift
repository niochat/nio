import SwiftUI
import MatrixSDK

import NioKit

struct IdentityServerSettingsContainerView: View {
    @EnvironmentObject var store: AccountStore

    var body: some View {
        IdentityServerSettingsView()
    }
}

struct ButtonModifier: ViewModifier {
    @AppStorage("accentColor") private var accentColor: Color = .purple

    func body(content: Content) -> some View {
        content
            .foregroundColor(.white)
            .font(.headline)
            .padding()
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(accentColor))
            .padding(.bottom)
    }
}

extension View {
    func customButton() -> ModifiedContent<Self, ButtonModifier> {
        return modifier(ButtonModifier())
    }
}

extension Text {
    func customTitleText() -> Text {
        self
            .fontWeight(.black)
            .font(.system(size: 36))
    }
}

struct InformationDetailView: View {
    @AppStorage("accentColor") private var accentColor: Color = .purple

    var title: String = ""
    var subTitle: String = ""
    var imageName: String = ""

    var body: some View {
        HStack(alignment: .center) {
            Image(systemName: imageName)
                .font(.largeTitle)
                .foregroundColor(accentColor)
                .padding()
                .accessibility(hidden: true)
                .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .accessibility(addTraits: .isHeader)
                    .textCase(.none)

                Text(subTitle)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textCase(.none)
            }
        }
        .padding(.top)
    }
}

struct InformationContainerView: View {
    @EnvironmentObject private var store: AccountStore

    var body: some View {
        VStack(alignment: .leading) {
            InformationDetailView(
                title: L10n.SettingsIdentityServer.data,
                subTitle: L10n.SettingsIdentityServer.dataText(store.session?.myUserId ?? "@username:server.org"),
                imageName: "arrow.up.doc"
            )

            InformationDetailView(
                title: L10n.SettingsIdentityServer.match,
                subTitle: L10n.SettingsIdentityServer.matchText,
                imageName: "magnifyingglass"
            )

            InformationDetailView(title: L10n.SettingsIdentityServer.closedFederation,
                                  subTitle: L10n.SettingsIdentityServer.closedFederationText,
                                  imageName: "globe"
            )

            InformationDetailView(title: L10n.SettingsIdentityServer.optionalContactSync,
                                  subTitle: L10n.SettingsIdentityServer.optionalContactSyncText,
                                  imageName: "person")
        }
        .padding(.horizontal)
    }
}

struct TitleView: View {
    @AppStorage("accentColor") private var accentColor: Color = .purple

    var body: some View {
        VStack {
            Image(systemName: "person.3")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 180, alignment: .center)
                .accessibility(hidden: true)
                .foregroundColor(accentColor)

            Text(L10n.SettingsIdentityServer.dataPrivacy)
                .customTitleText()

            Text(L10n.SettingsIdentityServer.title)
                .customTitleText()
                .foregroundColor(accentColor)
        }
    }
}

struct IdentityServerInfoView: View {
    @AppStorage("accentColor") private var accentColor: Color = .purple

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
            ScrollView {
                VStack(alignment: .center) {

                    Spacer()

                    TitleView()

                    InformationContainerView()

                    Spacer(minLength: 30)

                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text(L10n.SettingsIdentityServer.continue)
                            .customButton()
                    }
                    .padding(.horizontal)

                    Spacer()

                    Link(
                        L10n.SettingsIdentityServer.learnMore,
                        destination: URL(string: "https://matrix.org/legal/identity-server-privacy-notice-1")!
                    )
                    .foregroundColor(accentColor)
                }
            }
            .padding(.vertical)
        }
}

struct IdentityServerSettingsView: View {
    @AppStorage("identityServerBool") private var identityServerBool: Bool = false
    @AppStorage("identityServer") private var identityServer: String = "https://vector.im"
    @AppStorage("locSyncContacts") private var locSyncContacts: Bool = false
    @AppStorage("matrixUsers") private var matrixUsersJSON: String = ""

    @EnvironmentObject var store: AccountStore

    @State private var showModal = false
    @State private var showContactStateWarning = false

    var identityServerInfo: some View {
        Button(action: {
            showModal.toggle()
        }) {
            HStack {
                Text(L10n.SettingsIdentityServer.title)
                Image(systemName: "info.circle")
            }
        }
        .fullScreenCover(isPresented: $showModal, content: IdentityServerInfoView.init)
    }

    var body: some View {
        Section(header: identityServerInfo) {
            Toggle(
                L10n.SettingsIdentityServer.toggle,
                isOn: $identityServerBool
            ).onChange(
                of: identityServerBool,
                perform: syncIdentityServer(isSync:)
            )
            if identityServerBool {
                TextField(L10n.SettingsIdentityServer.url, text: $identityServer)
                Toggle(
                    L10n.SettingsIdentityServer.contactSync,
                    isOn: Binding(
                        get: { Contacts.hasPermission() && locSyncContacts },
                        set: { status in
                            locSyncContacts = status
                            if locSyncContacts && !Contacts.hasPermission() {
                                self.showContactStateWarning.toggle()
                            }
                        }
                    )
                )
                .onChange(of: locSyncContacts, perform: syncContacts(isSync:))
                .alert(isPresented: $showContactStateWarning) {
                      Alert(
                        title: Text(L10n.SettingsIdentityServer.permissionAlertTitle),
                        message: Text(L10n.SettingsIdentityServer.permissionAlertBody),
                        primaryButton: .cancel(Text(L10n.SettingsIdentityServer.permissionCancelButton)),
                        secondaryButton: .default(Text(L10n.SettingsIdentityServer.permissionSettingsButton), action: {
                          if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                          }
                        }))
                    }
                Button(action: {
                    self.matrixUsersJSON = ""
                    self.syncContacts(isSync: locSyncContacts)
                }, label: {
                    Text(verbatim: "Force Sync")
                })
            }
        }
    }

    private func syncIdentityServer(isSync: Bool) {
        if isSync {
            store.setIdentityService()
        } else {
            locSyncContacts = false
        }
    }

    private func syncContacts(isSync: Bool) {
        if isSync {
            store.updateMatrixContacts()
        }
    }
}
