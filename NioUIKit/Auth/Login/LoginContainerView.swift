//
//  LoginContainerView.swift
//  Nio
//
//  Created by Finn Behrens on 24.03.22.
//

import MatrixClient
import OSLog
import SwiftUI

public struct LoginContainerView: View {
    let callback: (MatrixHomeserver, MatrixLogin) -> Void
    @State private var matrixClient: MatrixClient?

    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "login")

    @State private var currentState: RegisterContainer.CurrentState = .`init`
    @State private var currentServer: String = "matrix.org"

    @State private var username: String = ""
    @State private var password: String = ""

    public init(callback: @escaping ((MatrixHomeserver, MatrixLogin) -> Void)) {
        self.callback = callback
    }

    public var body: some View {
        switch currentState {
        case .`init`:
            ProgressView()
                .task {
                    Task {
                        await self.probeServer()
                    }
                }
        case .login:
            VStack {
                Button(currentServer) {
                    currentState = .server
                }

                TextField("Username", text: $username)

                SecureField("Password", text: $password)

                Button("Login") {
                    currentState = .working
                    Task {
                        await self.login()
                    }
                }
            }
        case .server:
            AuthServerPicker(currentServer: currentServer, dismissCallback: {
                self.currentState = .login
            }, okCallback: { values in
                self.currentServer = values.serverName
                self.matrixClient = MatrixClient(homeserver: values.homeserver)
                self.currentState = .login
            }, checkRegister: false, logger: logger)
        case .flow:
            Text("Flows should not happen yet")
        // TODO: ??
        default:
            ProgressView().task {
                logger.info("showing view: \(String(describing: currentState))")
            }
        }
    }

    private func probeServer() async {
        let (homeserver, state, _) = await AuthServerPicker.probeServer(server: currentServer, logger: logger, checkRegister: false)

        guard state.canLogin,
              let homeserver = homeserver
        else {
            logger.fault("Default server cannot register")
            return
        }

        matrixClient = MatrixClient(homeserver: homeserver)
        currentState = .login
    }

    private func login() async {
        guard let matrixClient = matrixClient else {
            fatalError("Cannot login without probing the server")
        }

        do {
            let login = try await matrixClient.login(username: username, password: password, displayName: "Nio")

            callback(matrixClient.homeserver, login)
        } catch {
            fatalError(String(describing: error))
        }
    }
}

struct LoginContainerView_Previews: PreviewProvider {
    static var previews: some View {
        LoginContainerView { _, _ in
        }
    }
}
