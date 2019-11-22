import Foundation
import Combine
import SwiftMatrixSDK

class MatrixStore<State, Action>: ObservableObject {
    @Published private(set) var state: State

    private let reducer: Reducer<State, Action>
    private var cancellables: Set<AnyCancellable> = []

    init(initialState: State, reducer: Reducer<State, Action>) {
        self.state = initialState
        self.reducer = reducer
    }

    func send(_ action: Action) {
        reducer.reduce(&state, action)
    }

    func send<E: Effect>(_ effect: E) where E.Action == Action {
        effect.mapToAction()
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: send)
            .store(in: &cancellables)
    }
}

// MARK: States

struct AppState {
    var client: MXRestClient?
    var session: MXSession?

    var credentials: MXCredentials?
    var isLoggedIn: Bool {
        credentials != nil
    }

    var recentRooms: [MXRoom]?
    var publicRooms: MXPublicRoomsResponse?
}

// MARK: Side Effects

protocol Effect {
    associatedtype Action
    func mapToAction() -> AnyPublisher<Action, Never>
}

enum SideEffect: Effect {
    case login(username: String, password: String, client: MXRestClient)
    case start(session: MXSession)
    case publicRooms(client: MXRestClient)

    func mapToAction() -> AnyPublisher<AppAction, Never> {
        switch self {
        case let .login(username: username, password: password, client: client):
            return client
                .nio_login(username: username, password: password)
                .replaceError(with: MXCredentials()) // FIXME
                .map { AppAction.loggedIn($0) }
                .eraseToAnyPublisher()
        case .start(session: let session):
            return session
                .nio_start()
                .replaceError(with: MXSession()) // FIXME
                .map { AppAction.session($0) }
                .eraseToAnyPublisher()
        case .publicRooms(let client):
            return client
                .nio_publicRooms()
                .replaceError(with: MXPublicRoomsResponse()) // FIXME
                .map { AppAction.publicRooms($0) }
                .eraseToAnyPublisher()
        }
    }
}

// MARK: Actions

enum AppAction {
    case client(MXRestClient)
    case loggedIn(MXCredentials)
    case session(MXSession)
    case recentRooms
    case publicRooms(MXPublicRoomsResponse)
}

// MARK: Reducer

struct Reducer<State, Action> {
    let reduce: (inout State, Action) -> Void
}

let appReducer: Reducer<AppState, AppAction> = Reducer { state, action in
    print(action)
    switch action {
    case .client(let client):
        state.client = client
    case .loggedIn(let credentials):
        state.credentials = credentials
    case .session(let session):
        state.session = session
    case .recentRooms:
        state.recentRooms = state.session?.rooms
    case .publicRooms(let response):
        state.publicRooms = response
    }
}
