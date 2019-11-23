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
    var loginState: LoginState = .loggedOut

    var recentRooms: [MXRoom]?
    var publicRooms: MXPublicRoomsResponse?
}

enum LoginState {
    case loggedOut
    case authenticating
    case failure(Error)
    case loggedIn
}

// MARK: Side Effects

protocol Effect {
    associatedtype Action
    func mapToAction() -> AnyPublisher<Action, Never>
}

enum SideEffect: Effect {
    case login(username: String, password: String, homeserver: URL)
    case publicRooms(client: MXRestClient)

    func mapToAction() -> AnyPublisher<AppAction, Never> {
        switch self {
        case let .login(username: username, password: password, homeserver: homeserver):
            return MatrixServices.shared
                .login(username: username, password: password, homeserver: homeserver)
                .replaceError(with: .loggedOut) // FIXME
                .map { AppAction.loginState($0) }
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
    case loginState(LoginState)
    case recentRooms
    case publicRooms(MXPublicRoomsResponse)
}

// MARK: Reducer

struct Reducer<State, Action> {
    let reduce: (inout State, Action) -> Void
}

let appReducer: Reducer<AppState, AppAction> = Reducer { state, action in
    print("👉 ACTION: \(action)")
    switch action {
    case .loginState(let loginState):
        state.loginState = loginState
    case .recentRooms:
        let recentConversations = MatrixServices.shared.session?.rooms
            .sorted { lhs, rhs in
                lhs.summary.lastMessageDate > rhs.summary.lastMessageDate
            }
        state.recentRooms = recentConversations
    case .publicRooms(let response):
        state.publicRooms = response
    }
}
