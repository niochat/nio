import Combine
import Foundation
import KeychainAccess
import Intents
import MatrixSDK
import os

public enum LoginState {
    case loggedOut
    case authenticating
    case failure(Error)
    case loggedIn(userId: String)
    
    public var isAuthenticating: Bool {
        switch self {
        case .authenticating:
            return true
        default:
            return false
        }
    }
    
    public func waitForLogin() async {
        while self.isAuthenticating {
            print("trying to authenticate")
            //await Task.sleep(20_000)
        }
    }
}

@MainActor
public class AccountStore: ObservableObject {
    static let logger = Logger(subsystem: "chat.nio.chat", category: "AccountStore")
    
    public static let shared = AccountStore()
    
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
        if CommandLine.arguments.contains("-clear-stored-sk-search-iterms") {
            print("🗑 cleared stored sk search items from Siri")
            async {
                await Self.deleteSkItems()
            }
        }
        
        let developmentTeam = Bundle.main.infoDictionary?["DevelopmentTeam"] as? String

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

            try await self.setPusher()
        } catch {
            loginState = .failure(error)
        }
    }

    public func logout() async {
        credentials?.clear(from: keychain)

        do {
            try await session?.logout()
            try await self.setPusher(enable: false)
            loginState = .loggedOut
        } catch {
            // Close the session even if the logout request failed
            loginState = .loggedOut
        }
        await NSUserActivity.deleteAllSavedUserActivities()
    }
    
    public static func deleteSkItems() async {
        await NSUserActivity.deleteAllSavedUserActivities()
        do {
            try await INInteraction.deleteAll()
            Self.logger.debug("deleted ININteractions")
        } catch {
            Self.logger.warning("failed to delete INInteractions: \(error.localizedDescription)")
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
    
    public func findRoom(id: MXRoom.MXRoomId) -> NIORoom? {
        return self.rooms.filter({ $0.id == id }).first
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
    
    // MARK: - Push Notifications
    internal var pushKey: String?
    
    public func setPusher(key: Data, enable: Bool = true) async throws {
        let base = key.base64EncodedString()
        try await setPusher(stringKey: base, enable: enable)
    }
    
    public func setPusher(stringKey: String, enable: Bool = true) async throws {
        if pushKey != nil {
            Self.logger.warning("Pushkey already set to \(self.pushKey!)")
        }
        self.pushKey = stringKey
        
        try await setPusher(enable: enable)
    }
    
    /// function is also used to reset the push config
    // TODO: lang, dynamic pusher
    public func setPusher(enable: Bool = true) async throws {
        guard let session = self.session else {
            throw AccountStoreError.noSessionOpened
        }
        guard let pushKey = self.pushKey else {
            throw AccountStoreError.noPuskKey
        }

        let appId = Bundle.main.bundleIdentifier ?? "nio.chat"
        let lang = NSLocale.preferredLanguages.first ?? "en-US"
        
        let data: [String : Any] = [
            "url": "https://dev.matrix-push.kloenk.dev/_matrix/push/v1/notify",
            "format": "event_id_only",
            "default_payload": [
                "aps": [
                    "mutable-content": 1,
                    "content-available": 1,
                    "alert": [
                        "loc-key": "MESSAGE",
                        "loc-args": [],
                    ]
                ]
            ]
        ];
        
        let pushers = try await session.matrixRestClient.pushers()
        if pushers.count != 0 {
            Self.logger.debug("got pushers: \(String(describing: pushers))")
        }
        try await session.matrixRestClient.setPusher(puskKey: pushKey, kind: enable ? .http : .none, appId: appId, appDisplayName: "Nio", deviceDisplayName: "NioiOS", profileTag: "gloaaabal", lang: lang, data: data, append: false)
        //session.matrixRestClient.setPusher(pushKey: key, kind: .http, appId: <#T##String#>, appDisplayName: <#T##String#>, deviceDisplayName: <#T##String#>, profileTag: <#T##String#>, lang: <#T##String#>, data: <#T##[String : Any]#>, append: <#T##Bool#>, completion: <#T##(MXResponse<Void>) -> Void#>)
        //self.session?.matrixRestClient.setPusher(pushKey: <#T##String#>, kind: .http, appId: <#T##String#>, appDisplayName: <#T##String#>, deviceDisplayName: <#T##String#>, profileTag: <#T##String#>, lang: <#T##String#>, data: <#T##[String : Any]#>, append: <#T##Bool#>, completion: <#T##(MXResponse<Void>) -> Void#>)
    }
    /*func setPusher() {
        self.session?.matrixRestClient.setPusher(pushKey: <#T##String#>, kind: .http, appId: <#T##String#>, appDisplayName: <#T##String#>, deviceDisplayName: <#T##String#>, profileTag: <#T##String#>, lang: <#T##String#>, data: <#T##[String : Any]#>, append: <#T##Bool#>, completion: <#T##(MXResponse<Void>) -> Void#>)
    }*/
}

enum AccountStoreError: Error {
    case noCredentials
    case noSessionOpened
    case invalidUrl
    case noPuskKey
}
