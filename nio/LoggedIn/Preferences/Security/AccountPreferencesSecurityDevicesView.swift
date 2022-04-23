//
//  AccountPreferencesSecurityDevicesView.swift
//  Nio
//
//  Created by Finn Behrens on 22.04.22.
//

import LocalAuthentication
import MatrixClient
import NioKit
import SwiftUI

struct AccountPreferencesSecurityDevicesView: View {
    @EnvironmentObject var account: NioAccount
    @EnvironmentObject var store: NioAccountStore

    @State private var devices: [MatrixDevice] = []
    @State private var ownDevice: MatrixDevice?

    @State private var selection = Set<String>()
    // @State private var editMode = EditMode.inactive
    @Environment(\.editMode) var editMode

    var body: some View {
        List(selection: $selection) {
            Section("This device") {
                if let ownDevice = ownDevice {
                    NavigationLink {
                        DeviceDetailView(device: ownDevice, isSelf: true)
                            .environmentObject(account)
                    } label: {
                        DeviceView(device: ownDevice)
                    }
                } else {
                    Text(account.info.deviceID)
                }
            }

            // TODO: verified/unverified devices sections?
            if !devices.isEmpty {
                Section("Devices") {
                    ForEach(devices, id: \.deviceID) { device in
                        NavigationLink {
                            DeviceDetailView(device: device)
                                .environmentObject(account)
                        } label: {
                            DeviceView(device: device)
                        }
                        .tag(device.id)
                    }
                    .onDelete(perform: delete)
                }
            }

            Section {
                Button("Logout All", role: .destructive, action: logoutAll)
            }
        }
        .refreshable {
            await self.updateDevices()
        }
        .toolbar {
            EditButton()
        }
        .toolbar {
            ToolbarItem(id: "delete", placement: .bottomBar, showsByDefault: false) {
                if editMode?.wrappedValue == .active {
                    Button("Delete", role: .destructive) {
                        print("TODO: Mass delete")
                        withAnimation {
                            // self.editMode = .inactive
                        }
                    }
                    .disabled(self.selection.isEmpty)
                }
            }
        }
        .onAppear {
            self.updateDevices()
        }
    }

    private func updateDevices() {
        Task(priority: .high) {
            await self.updateDevices()
        }
    }

    private func updateDevices() async {
        NioAccountStore.logger.debug("Updating device list")
        do {
            var devices = try await account.core.client.getDevices().devices

            if let ownIndex = devices.firstIndex(where: { $0.deviceID == account.info.deviceID }) {
                ownDevice = devices.remove(at: ownIndex)
            }

            self.devices = devices
        } catch {
            NioAccountStore.logger.fault("Failed to get device list: \(error.localizedDescription)")
        }
    }

    private func delete(at offsets: IndexSet) {
        let idsToDelete = offsets.map { self.devices[$0].deviceID }

        _ = idsToDelete.compactMap { id in
            self.logoutOther(deviceID: id)
        }
    }

    // TODO: implement
    private func logoutOther(deviceID: String) {
        Task(priority: .medium) {
            print("deleting \(deviceID)")
            /* do {
                 //let delete = try await self.store.accounts[account.userID!]?.matrixCore.client.deleteDevice(deviceID: deviceID)
                 //print(delete as Any)
                 // TODO: do interactive auth
             } catch {
                 print(error)
             } */
        }
    }

    private func logoutAll() {
        Task(priority: .userInitiated) {
            await self.logoutAll()
        }
    }

    private func logoutAll() async {
        do {
            let laContext = LAContext()
            if laContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) {
                if try await laContext.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: "Logout all devices"
                ) {
                    try await doLogoutAll()
                }
            } else {
                fatalError("No legacy methode implemented to fallback on missing deviceOwnerAuthentication")
            }
        } catch {
            NioAccountStore.logger.fault("Failed to logout all accounts: \(error.localizedDescription)")
        }
    }

    private func doLogoutAll() async throws {
        let account = try await store.removeAccount(account.mxID)
        try await account?.core.client.logoutAll()
    }
}

extension AccountPreferencesSecurityDevicesView {
    struct DeviceView: View {
        let device: MatrixDevice
        let subText: String

        init(device: MatrixDevice) {
            self.device = device

            var subText = ""
            if let lastSeen = device.lastSeen {
                subText.append("Last seen \(lastSeen.formatted()) ")
            }

            if let lastSeenIP = device.lastSeenIP {
                subText.append("at \(lastSeenIP)")
            }

            self.subText = subText
        }

        var body: some View {
            VStack(alignment: .leading) {
                Text(device.displayName ?? device.deviceID)
                    .font(.subheadline)

                Text(subText)
                    .font(.footnote)
            }
        }
    }

    struct DeviceDetailView: View {
        @EnvironmentObject private var account: NioAccount

        @Environment(\.dismiss) private var dissmis

        let device: MatrixDevice

        let isSelf: Bool

        @State var displayName: String
        @State var working: Bool = false

        init(device: MatrixDevice, isSelf: Bool = false) {
            self.device = device
            self.isSelf = isSelf

            _displayName = State(initialValue: device.displayName ?? "")
        }

        var body: some View {
            List {
                // Display Name
                HStack {
                    Text("Display Name")
                    Spacer(minLength: 20)

                    TextField("Display Name", text: $displayName)
                        .multilineTextAlignment(.trailing)
                        .disabled(working)
                }

                // Session
                HStack {
                    Text("Session")
                    Spacer(minLength: 20)

                    Text(device.deviceID)
                        .foregroundColor(.gray)
                }

                // IP
                if let lastSeenIP = device.lastSeenIP {
                    HStack {
                        Text("Last Seen IP")
                        Spacer(minLength: 20)

                        Text(lastSeenIP)
                            .foregroundColor(.gray)
                    }
                }

                if let lastSeen = device.lastSeen {
                    HStack {
                        Text("Last Seen")
                        Spacer(minLength: 20)

                        Text(lastSeen.formatted())
                            .foregroundColor(.gray)
                    }
                }
            }
            .textSelection(.enabled)
            .navigationTitle("Session \(device.displayName ?? device.deviceID)")
            .toolbar {
                ToolbarItem {
                    Button(action: {
                        self.setDisplayName()
                    }) {
                        Text("Save")
                    }
                    .disabled(working)
                }
            }
        }

        private func setDisplayName() {
            working = true
            Task(priority: .userInitiated) {
                do {
                    try await account.core.client.setDeviceDisplayName(displayName, device: device)
                    self.dissmis()
                } catch {
                    NioAccountStore.logger.fault("Failed to set display name: \(error.localizedDescription)")
                }
                self.working = false
            }
        }
    }
}

struct AccountPreferencesSecurityDevicesView_Previews: PreviewProvider {
    static var previews: some View {
        AccountPreferencesSecurityDevicesView()
    }
}
