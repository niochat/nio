import Combine
import Foundation
import KeychainAccess
import MatrixSDK

public enum LoginState {
    case loggedOut
    case authenticating
    case failure(Error)
    case loggedIn(userId: String)
}

@MainActor
public class AccountStore: ObservableObject {
    public var client: MXRestClient?
    public var session: MXSession?

    var fileStore: MXFileStore?
    var credentials: MXCredentials?

    let keychain = Keychain(
        service: "chat.nio.credentials",
        accessGroup: ((Bundle.main.infoDictionary?["DevelopmentTeam"] as? String) ?? "") + ".nio.keychain"
    )

    public init() {
        if CommandLine.arguments.contains("-clear-stored-credentials") {
            print("🗑 cleared stored credentials from keychain")
            MXCredentials
                .from(keychain)?
                .clear(from: keychain)
        }

        Configuration.setupMatrixSDKSettings()
        guard let credentials = MXCredentials.from(keychain) else {
            return
        }
        self.credentials = credentials
        loginState = .authenticating
        async {
            do {
                self.loginState = try await self.sync()
                self.session?.crypto.warnOnUnknowDevices = false
            } catch {
                print("Error on starting session with saved credentials: \(error)")
                self.loginState = .failure(error)
            }
        }
    }

    deinit {
        self.session?.removeListener(self.listenReference)
    }

    // MARK: - Login & Sync

    @Published public var loginState: LoginState = .loggedOut

    public func login(username: String, password: String, homeserver: URL) async {
        loginState = .authenticating

        client = MXRestClient(homeServer: homeserver, unrecognizedCertificateHandler: nil)
        client?.acceptableContentTypes = ["text/plain", "text/html", "application/json", "application/octet-stream", "any"]

        do {
            let credentials = try await client?.login(username: username, password: password)
            guard let credentials = credentials else {
                loginState = .failure(AccountStoreError.noCredentials)
                return
            }
            self.credentials = credentials
            credentials.save(to: keychain)
            loginState = try await sync()
            session?.crypto.warnOnUnknowDevices = false
        } catch {
            loginState = .failure(error)
        }
    }

    public func logout() async {
        credentials?.clear(from: keychain)

        do {
            try await session?.logout()
            loginState = .loggedOut
        } catch {
            // Close the session even if the logout request failed
            loginState = .loggedOut
        }
    }

    @available(*, deprecated, message: "Prefer async alternative instead")
    private func sync(completion: @escaping (Result<LoginState, Error>) -> Void) {
        async {
            do {
                let result = try await sync()
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func sync() async throws -> LoginState {
        guard let credentials = self.credentials else {
            throw AccountStoreError.noCredentials
        }

        client = MXRestClient(credentials: credentials, unrecognizedCertificateHandler: nil)
        session = MXSession(matrixRestClient: client!)
        fileStore = MXFileStore()

        try await session!.setStore(fileStore!)
        try await session?.start()
        return .loggedIn(userId: credentials.userId!)
    }

    // MARK: - Rooms

    var listenReference: Any?

    public func startListeningForRoomEvents() {
        // roomState is nil for presence events, just for future reference
        listenReference = session?.listenToEvents { event, direction, roomState in
            let affectedRooms = self.rooms.filter { $0.summary.roomId == event.roomId }
            for room in affectedRooms {
                room.add(event: event, direction: direction, roomState: roomState as? MXRoomState)
            }
            self.objectWillChange.send()
        }
    }

    private var roomCache = [ObjectIdentifier: NIORoom]()

    private func makeRoom(from mxRoom: MXRoom) -> NIORoom {
        let room = NIORoom(mxRoom)
        roomCache[mxRoom.id] = room
        return room
    }

    public var rooms: [NIORoom] {
        guard let session = self.session else { return [] }

        let rooms = session.rooms
            .map { roomCache[$0.id] ?? makeRoom(from: $0) }
            .sorted { $0.summary.lastMessageDate > $1.summary.lastMessageDate }

        updateUserDefaults(with: rooms)
        return rooms
    }

    private func updateUserDefaults(with rooms: [NIORoom]) {
        let roomItems = rooms.map { RoomItem(room: $0.room) }
        do {
            let data = try JSONEncoder().encode(roomItems)
            UserDefaults.group.set(data, forKey: "roomList")
        } catch {
            print("An error occured: \(error)")
        }
    }

    var listenReferenceRoom: Any?

    @available(*, deprecated, message: "Prefer paginating on the room instead")
    public func paginate(room: NIORoom, event: MXEvent) {
        let timeline = room.room.timeline(onEvent: event.eventId)
        listenReferenceRoom = timeline?.listenToEvents { event, direction, roomState in
            if direction == .backwards {
                room.add(event: event, direction: direction, roomState: roomState)
            }
            self.objectWillChange.send()
        }
        timeline?.resetPaginationAroundInitialEvent(withLimit: 40) { _ in
            self.objectWillChange.send()
        }
    }
}

enum AccountStoreError: Error {
    case noCredentials
    case invalidUrl
}
