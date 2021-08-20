import Foundation
import Combine
import MatrixSDK
import KeychainAccess

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
        accessGroup: ((Bundle.main.infoDictionary?["DevelopmentTeam"] as? String) ?? "") + ".nio.keychain")

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
        self.loginState = .authenticating
        Task.init(priority: .userInitiated) {
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
        self.loginState = .authenticating

        self.client = MXRestClient(homeServer: homeserver, unrecognizedCertificateHandler: nil)
        do {
            let credentials = try await self.client?.login(username: username, password: password)
            self.credentials = credentials
            credentials!.save(to: self.keychain)
            self.loginState = try await self.sync()
        } catch {
            print("Error on starting session with new credentials: \(error)")
            self.loginState = .failure(error)
        }
    }

    public func logout() async -> LoginState {
        self.credentials?.clear(from: keychain)
        
        do {
            try await self.session!.logout()
        } catch {
            self.loginState = .failure(error)
            return self.loginState
        }
        self.loginState = .loggedOut
        return self.loginState
    }

    private func sync() async throws -> LoginState {
        guard let credentials = self.credentials else {
            throw AccountStoreError.noCredentials
        }
        
        self.client = MXRestClient(credentials: credentials, unrecognizedCertificateHandler: nil)
        self.session = MXSession(matrixRestClient: self.client!)
        self.fileStore = MXFileStore()
        
        try await self.session!.setStore(fileStore!)
        try await self.session!.start()
        return .loggedIn(userId: credentials.userId!)
    }

    // MARK: - Rooms

    var listenReference: Any?

    public func startListeningForRoomEvents() {
        // roomState is nil for presence events, just for future reference
        listenReference = self.session?.listenToEvents { event, direction, roomState in
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
    
    public func setPusher(url: String, enable: Bool = true, deviceToken: String) async throws {
        guard let session = session else {
            throw AccountStoreError.noSession
        }
        
        let appId = Bundle.main.bundleIdentifier ?? "nio.chat"
        let lang = NSLocale.preferredLanguages.first ?? "en-US"
        
        // TODO: generate a pusher profile and use it, instead of a (hopefully) not existing tag
        let profileTag = "gloaable"
        
        let data: [String: Any] = [
            "url": "https://\(url)/_matrix/push/v1/notify",
            "format": "event_id_only",
            "default_payload": [
                "aps": [
                    "mutable-content": 1,
                    "content-available": 1,
                    // TODO: add acount info, if we ever enable multi accounting
                    "alert": [
                        "loc-key": "MESSAGE",
                        "loc-args": [],
                    ]
                ]
            ]
        ]
        
        try await session.matrixRestClient.setPusher(
            pushKey: deviceToken,
            kind: enable ? .http : .none,
            appId: appId,
            appDisplayName: "Nio",
            deviceDisplayName: "Nio iOS",
            profileTag: profileTag,
            lang: lang,
            data: data,
            append: false
        )
    }
}

enum AccountStoreError: Error {
    case noCredentials
    case noSession
    case invalidUrl
}
