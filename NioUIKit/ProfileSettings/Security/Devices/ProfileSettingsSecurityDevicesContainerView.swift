//
//  ProfileSettingsSecurityDevicesContainerView.swift
//  Nio
//
//  Created by Finn Behrens on 31.03.22.
//

import MatrixClient
import MatrixCore
import NioKit
import SwiftUI

struct ProfileSettingsSecurityDevicesContainerView: View {
    @EnvironmentObject var account: MatrixAccount
    @EnvironmentObject var store: NioAccountStore

    @State private var devices: [MatrixDevice] = []
    @State private var ownDevice: MatrixDevice?

    @State private var selection = Set<String>()
    @State private var editMode = EditMode.inactive

    var body: some View {
        List(selection: $selection) {
            Section(header: Text("This device")) {
                if let ownDevice = ownDevice {
                    NavigationLink {
                        ProfileSettingsSecurityDeviceDetailView(device: ownDevice, isSelf: true)
                            .environmentObject(account)
                    } label: {
                        ProfileSettingsSecurityDeviceView(device: ownDevice)
                    }
                } else {
                    Text(account.deviceID ?? "Unknown Device")
                }
            }

            // TODO: verified/unverified devices sections?
            Section(header: Text("Devices")) {
                ForEach(devices, id: \.deviceID) { device in
                    NavigationLink {
                        ProfileSettingsSecurityDeviceDetailView(device: device)
                            .environmentObject(account)
                    } label: {
                        ProfileSettingsSecurityDeviceView(device: device)
                    }
                    .tag(device.id)
                }
                .onDelete(perform: delete)
            }
        }
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItem(id: "delete", placement: .bottomBar, showsByDefault: false) {
                if editMode == .active {
                    Button("Delete", role: .destructive) {
                        print("TODO: Mass delete")
                        withAnimation {
                            self.editMode = .inactive
                        }
                    }
                    .disabled(self.selection.isEmpty)
                }
            }
        }
        .refreshable {
            await self.updateDevices()
        }
        .toolbar {
            ToolbarItem {
                if editMode == .active {
                    Button("Cancel") {
                        self.selection.removeAll()
                        withAnimation {
                            self.editMode = .inactive
                        }
                    }
                } else {
                    Button("Edit") {
                        withAnimation {
                            self.editMode = .active
                        }
                    }
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
            var devices = try await store.accounts[account.userID!]?.matrixCore.client.getDevices().devices ?? []

            if let ownIndex = devices.firstIndex(where: { $0.deviceID == account.deviceID ?? "" }) {
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

    private func logoutOther(deviceID: String) {
        Task(priority: .medium) {
            print("deleting \(deviceID)")
            do {
                let delete = try await self.store.accounts[account.userID!]?.matrixCore.client.deleteDevice(deviceID: deviceID)
                print(delete as Any)
                // TODO: do interactive auth
            } catch {
                print(error)
            }
        }
    }
}

struct ProfileSettingsSecurityDeviceView: View {
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

struct ProfileSettingsSecurityDeviceDetailView: View {
    @EnvironmentObject var account: MatrixAccount
    @EnvironmentObject var store: NioAccountStore

    @Environment(\.dismiss) private var dismiss

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
            Section(header: Text("Session info")) {
                HStack {
                    Text("Display Name")
                    Spacer(minLength: 20)

                    TextField("Display Name", text: $displayName)
                        .multilineTextAlignment(.trailing)
                        .disabled(working)
                }

                HStack {
                    Text("Session")
                    Spacer(minLength: 20)

                    Text(device.deviceID)
                        .foregroundColor(.gray)
                }

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
        }
        .navigationTitle("Manage session")
        .toolbar {
            ToolbarItem {
                Button(action: {
                    self.setDisplayName()
                }) {
                    Text("Save")
                }
                .disabled(displayName == device.displayName || working)
            }
        }
    }

    private func setDisplayName() {
        working = true
        Task(priority: .userInitiated) {
            do {
                let core = store.accounts[account.userID!]!.matrixCore
                try await core.client.setDeviceDisplayName(displayName, deviceID: device.deviceID)
                self.dismiss()
            } catch {
                NioAccountStore.logger.fault("Failed to set device display name")
            }
            self.working = false
        }
    }
}

struct ProfileSettingsSecurityDevicesContainerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // ProfileSettingsSecurityDevicesContainerView()

            ProfileSettingsSecurityDeviceDetailView(device: .init(deviceID: "EXMPLA", displayName: "Exmaple Device", lastSeenIP: "192.0.2.53", lastSeen: .now))
        }
    }
}
