import Combine
import SwiftMatrixSDK

// MARK: States

struct AppState {
    var credentials: MXCredentials?
    var isLoggedIn: Bool {
        return credentials != nil
    }
}

// MARK: Side Effects

protocol Effect {
    associatedtype Action
    func mapToAction() -> AnyPublisher<Action, Never>
}

enum SideEffect: Effect {
    case login(username: String, password: String, homeserver: URL)

    func mapToAction() -> AnyPublisher<AppAction, Never> {
        switch self {
        case let .login(username: username, password: password, homeserver: homeserver):
//            return dependencies.matrixService
            let client = MXRestClient(homeServer: homeserver, unrecognizedCertificateHandler: nil)
            return client
                .loginPublisher(username: username, password: password)
                .replaceError(with: MXCredentials()) // FIXME
                .map { AppAction.loggedIn($0) }
                .eraseToAnyPublisher()
        }
    }
}

// MARK: Actions

enum AppAction {
    case loggedIn(MXCredentials)
}

// MARK: Reducer

struct Reducer<State, Action> {
    let reduce: (inout State, Action) -> Void
}

let appReducer: Reducer<AppState, AppAction> = Reducer { state, action in
    switch action {
    case let .loggedIn(credentials):
        state.credentials = credentials
    }
}
