//
//  AuthServerPicker.swift
//  Nio
//
//  Created by Finn Behrens on 24.03.22.
//

import MatrixClient
import os.log
import SwiftUI

struct AuthServerPicker: View {
    @State var newServer: String
    let logger: Logger
    let checkRegister: Bool

    let dismissCallback: () -> Void
    let okCallback: (Values) -> Void
    @State var serverState: ServerState = .ok
    @State var working: Bool = false

    init(currentServer: String = "", dismissCallback: @escaping (() -> Void), okCallback: @escaping ((Values) -> Void), checkRegister: Bool = false, logger: Logger = Logger()) {
        self.checkRegister = checkRegister
        self.dismissCallback = dismissCallback
        self.okCallback = okCallback
        self.logger = logger
        _newServer = .init(initialValue: currentServer)
    }

    var body: some View {
        if !working {
            VStack {
                HStack {
                    Button("Cancel", role: .cancel) {
                        dismissCallback()
                    }
                    Spacer(minLength: 0)

                    Button("Ok") {
                        self.working = true
                        Task {
                            await self.probeServerCallback()
                        }
                    }
                }

                Spacer(minLength: 0)

                if serverState == .notFound {
                    Text("Server not found")
                        .bold()
                        .foregroundColor(.red)
                } else if !serverState.canRegister {
                    Text("Registration not supported by Homeserver")
                        .bold()
                        .foregroundColor(.red)
                }

                Text("Decide where your account is hosted")
                    .bold()

                Text("We call the places where you can host your account 'homeservers'. Matrix.org is the biggest public homeserver in the world, so it's a good place for many.").fontWeight(.light)

                TextField("Homeserver", text: $newServer)
                #if os(iOS)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                #endif

                Spacer(minLength: 0)
            }
        } else {
            ProgressView()
        }
    }

    func probeServerCallback() async {
        working = true
        let (homeserver, state, auth) = await AuthServerPicker.probeServer(server: newServer, logger: logger, checkRegister: checkRegister)
        serverState = state

        if !state.canLogin || (checkRegister && !state.canRegister) {
            working = false
            return
        }
        guard let homeserver = homeserver else {
            logger.error("homeserver = nil")
            return
        }

        let values = Values(serverName: newServer, homeserver: homeserver, auth: auth)
        okCallback(values)
    }

    static func probeServer(server: String, logger: Logger, checkRegister: Bool = false) async -> (MatrixHomeserver?, ServerState, MatrixInteractiveAuth?) {
        var newServer = server
        if !newServer.hasPrefix("http") {
            newServer = "https://\(newServer)"
        }

        do {
            let homeserver = try await MatrixHomeserver(resolve: newServer)
            let client = MatrixClient(homeserver: homeserver)

            try await client.isReady()

            if checkRegister {
                do {
                    let registerFlows = try await client.getRegisterFlows()

                    return (homeserver, .ok, registerFlows)
                } catch let error as MatrixServerError {
                    if error.errcode == .Forbidden {
                        logger.info("Register is not supported by the homeserver")
                        return (homeserver, .noRegistration, nil)
                    } else {
                        throw error
                    }
                }
            }
            return (homeserver, .noRegistration, nil)
        } catch {
            logger.error("\(error.localizedDescription)")
        }

        return (nil, .notFound, nil)
    }

    enum ServerState {
        case notFound
        case noRegistration
        case ok

        var canRegister: Bool {
            self == .ok
        }

        var canLogin: Bool {
            self != .notFound
        }
    }

    struct Values {
        var serverName: String
        var homeserver: MatrixHomeserver
        var auth: MatrixInteractiveAuth?
    }
}

struct AuthServerPicker_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // AuthServerPicker()
        }
    }
}
