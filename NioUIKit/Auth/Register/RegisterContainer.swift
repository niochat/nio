//
//  RegisterContainer.swift
//  Nio
//
//  Created by Finn Behrens on 21.03.22.
//

import MatrixClient
import OSLog
import SwiftUI

public struct RegisterContainer: View {
    // TODO: callback functions

    var callback: (MatrixHomeserver, MatrixRegister) -> Void

    @State private var matrixClient: MatrixClient?
    @State private var session: String?

    var logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "register")

    @State private var registerFlows: MatrixInteractiveAuth?

    @State private var currentState: CurrentState = .`init`
    @State private var currentServer: String = "matrix.org"

    @State private var supportsEmail: Bool = false
    @State private var requiresEmail: Bool = false
    private var emailClientSecret: String = MatrixRegisterRequestEmailTokenRequest.generateClientSecret()
    @State private var emailSendAttempt: Int = 0
    @State private var emailSID: String?

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var email: String = ""

    public init(callback: @escaping ((MatrixHomeserver, MatrixRegister) -> Void)) {
        self.callback = callback
    }

    public var body: some View {
        switch currentState {
        case .`init`:
            ProgressView()
                .task {
                    Task {
                        await self.probeServer(currentServer)
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
            AuthServerPicker(currentServer: currentServer, dismissCallback: {
                self.currentState = .login
            }, okCallback: { values in
                self.currentServer = values.serverName
                self.matrixClient = MatrixClient(homeserver: values.homeserver)

                self.supportsEmail = values.auth!.isOptional(.email)
                self.requiresEmail = values.auth!.isRequierd(.email)

                self.registerFlows = values.auth

                self.currentState = .login

            }, checkRegister: true, logger: logger)
        case let .flow(flow):
            switch flow.flow {
            case .recaptcha:
                RegisterRecaptchaView(serverUrl: (matrixClient?.homeserver.url.url!)!, parameters: flow.params, callback: { token in
                    logger.debug("got recaptcha token: \(token)")
                    Task {
                        let auth = MatrixInteractiveAuthResponse(recaptchaResponse: token, session: session)
                        await self.next(response: auth)
                    }
                })
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
                RegisterFallbackView(session: session, flow: flow.flow, apiUrl: matrixClient!.homeserver.url) {
                    Task {
                        await self.next(response: MatrixInteractiveAuthResponse(session: session, type: nil))
                    }
                }
            }
        default:
            ProgressView()
        }
    }

    func probeServer(_ newServer: String) async {
        let (homeserver, state, auth) = await AuthServerPicker.probeServer(server: newServer, logger: logger, checkRegister: true)

        guard state.canRegister,
              let homeserver = homeserver,
              let auth = auth
        else {
            logger.fault("Default server cannot register")
            return
        }

        matrixClient = MatrixClient(homeserver: homeserver)
        currentState = .login

        supportsEmail = auth.isOptional(.email)
        requiresEmail = auth.isRequierd(.email)

        registerFlows = auth
        currentState = .login
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

        do {
            let register = try await matrixClient.register(password: password, username: username)
            callback(matrixClient.homeserver, register)
        } catch let error as MatrixServerError {
            guard let auth = error.interactiveAuth,
                  let session = auth.session
            else {
                throw error
            }

            self.session = session
            registerFlows = auth

            if auth.isOptional(notCompletedFlow: .email) {
                logger.debug("requesting email SID: \(emailSendAttempt)")
                let emailTokenRequest = try await matrixClient.requestEmailToken(clientSecret: emailClientSecret, email: email, sendAttempt: emailSendAttempt)

                emailSID = emailTokenRequest.sid
            }

            if let nextStage = auth.nextStageWithParams {
                logger.debug("entering stage: \(nextStage.flow.rawValue)")
                currentState = .flow(nextStage)
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
            callback(matrixClient.homeserver, register)
        } catch let error as MatrixServerError {
            guard let auth = error.interactiveAuth else {
                logger.warning("\(error.localizedDescription)")
                return
            }
            if session == nil {
                session = auth.session
            }
            currentState = .flow(auth.nextStageWithParams!)

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
internal struct RegisterContainerServerOptions: View {
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
            RegisterContainer(callback: { _, token in
                print("got token: \(token)")
            })
        }
    }
}
