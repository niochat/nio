//
//  RegisterContainer.swift
//  Nio
//
//  Created by Finn Behrens on 21.03.22.
//

import MatrixClient
import os
import SwiftUI

public struct RegisterContainer: View {
    // TODO: callback functions

    var callback: (MatrixRegister) -> Void

    @State private var matrixClient: MatrixClient?
    @State private var session: String?

    var logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "register")

    @State private var currentState: CurrentState = .`init`
    @State private var currentServer: String = "matrix.org"
    @State private var newServer: String = "matrix.org"

    @State private var supportsRegistration: Bool = true
    @State private var supportsEmail: Bool = false
    @State private var requiresEmail: Bool = false
    private var emailClientSecret: String = MatrixRegisterRequestEmailTokenRequest.generateClientSecret()
    @State private var emailSendAttempt: Int = 0
    @State private var emailSID: String?

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var email: String = ""

    public init(callback: @escaping ((MatrixRegister) -> Void)) {
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
                Text("Create account")
                    .bold()
                    .padding()

                RegisterContainerServerOptions()

                Button(currentServer) {
                    currentState = .server
                }

                TextField("Username", text: $username)
                #if os(macOS)
                    .textContentType(.username)
                #else
                    .textContentType(.nickname)
                #endif
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                #endif

                HStack {
                    SecureField("Password", text: $password)
                    SecureField("Confirm password", text: $confirmPassword)
                }

                if supportsEmail {
                    TextField("Email", text: $email)
                    #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    #endif
                }

                Button("Next") {
                    currentState = .working
                    Task {
                        try await self.next()
                    }
                }
                .padding()

            }.padding()

        case .server:
            VStack {
                HStack {
                    Button("Cancel", role: .cancel) {
                        currentState = .login
                    }
                    Spacer(minLength: 0)

                    Button("Ok") {
                        currentState = .working

                        Task {
                            await self.probeServer()
                        }
                    }
                }

                Spacer(minLength: 0)

                if !supportsRegistration {
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

        case let .flow(flow):
            switch flow.flow {
            /* case .recaptcha:
             RegisterRecaptchaView(serverUrl: currentServer, parameters: flow.params, callback: { token in
                 logger.debug("got recaptcha token: \(token)")
                 Task {
                     let auth = MatrixInteractiveAuthResponse(recaptchaResponse: token, session: session)
                     await self.next(response: auth)
                 }
             }) */
            case .terms:
                RegisterTermsView(parameters: flow.params) {
                    logger.debug("all terms accepted")
                    Task {
                        let auth = MatrixInteractiveAuthResponse(session: session, type: .terms)
                        await self.next(response: auth)
                    }
                }
            case .email:
                RegisterEmailView(resend: {
                    logger.debug("resending mail")
                    emailSendAttempt += 1
                    // FIXME: implement
                }, retry: {
                    Task {
                        logger.debug("retrying email")
                        if let emailSID = emailSID {
                            let auth = MatrixInteractiveAuthResponse(emailClientSecret: emailClientSecret, emailSID: emailSID, session: session)
                            await self.next(response: auth)
                        } else {
                            logger.warning("No EmailSID available")
                        }
                    }
                }, email: email)

            default:
                RegisterFallbackView(session: session, flow: flow.flow, apiUrl: matrixClient!.homeserver.url.url!)
            }
        default:
            ProgressView()
        }
    }

    func probeServer() async {
        do {
            if !newServer.hasPrefix("http") {
                newServer = "https://\(newServer)"
            }

            let homeserver = try await MatrixHomeserver(resolve: newServer)
            let client = MatrixClient(homeserver: homeserver)

            let registerFlows = try await client.getRegisterFlows()

            supportsEmail = registerFlows.isOptional(.email)
            requiresEmail = registerFlows.isRequierd(.email)

            matrixClient = client

            currentServer = newServer
            currentState = .login
        } catch let error as MatrixServerError {
            if error.errcode == .Forbidden {
                logger.info("Register is not supported by the homeserver")
                supportsRegistration = false
            } else {
                logger.error("\(error.localizedDescription)")
            }
            currentState = .server
        } catch {
            logger.error("\(error.localizedDescription)")

            currentState = .server
        }
    }

    // FIXME: don't throw
    func next() async throws {
        guard let matrixClient = matrixClient else {
            fatalError("server probing did not run, cannot register")
        }

        // TODO: check complexity
        guard password == confirmPassword else {
            logger.error("Password does not match")
            // TODO: print error
            return
        }

        var auth: MatrixInteractiveAuth?

        if session == nil {
            let register = try await matrixClient.register(password: password, username: username)

            if let register = register.successData {
                callback(register)
                return
            }

            if let interactive = register.interactiveData {
                session = interactive.session
                auth = interactive
            }
        }

        if let session = session {
            if let auth = auth {
                if auth.isOptional(notCompletedFlow: .email) {
                    logger.debug("requesting email SID: \(emailSendAttempt)")
                    let emailTokenRequest = try await matrixClient.requestEmailToken(clientSecret: emailClientSecret, email: email, sendAttempt: emailSendAttempt)

                    emailSID = emailTokenRequest.sid
                }

                if let nextStage = auth.nextStageWithParams {
                    currentState = .flow(nextStage)
                }

                print("next: \(String(describing: auth.nextStage))")
            }
        }
    }

    func next(response: MatrixInteractiveAuthResponse) async {
        currentState = .working
        guard let matrixClient = matrixClient else {
            fatalError("server probing did not run, cannot register")
        }

        do {
            let register = try await matrixClient.register(password: password, username: username, auth: response)

            switch register {
            case let .interactive(matrixInteractiveAuth):
                if session == nil {
                    session = matrixInteractiveAuth.session
                }
                currentState = .flow(matrixInteractiveAuth.nextStageWithParams!)
            case let .success(matrixRegister):
                callback(matrixRegister)
                return
            }
        } catch {
            logger.warning("\(error.localizedDescription)")
        }
    }

    enum CurrentState {
        case `init`
        case working
        case login
        case server
        case flow(MatrixInteractiveAuth.LoginFlowWithParams)
    }
}

/// View holding The Server Options info dialog and the container.
private struct RegisterContainerServerOptions: View {
    @State private var showPopover: Bool = false

    var body: some View {
        HStack {
            Text("Hosted account on")
            Spacer()
            Button(action: {
                showPopover.toggle()
            }) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
            }.popover(isPresented: $showPopover) {
                VStack {
                    Text("Server Options").bold().padding()

                    Text("You can use the custom server options to sign into other Matrix servers by specifying a different homeserver URL. This allows you to use Element with an existing Matrix account on a different homeserver.")
                }
                .padding()
            }
        }
    }
}

struct RegisterContainer_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RegisterContainer(callback: { token in
                print("got token: \(token)")
            })
        }
    }
}
