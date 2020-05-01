import Foundation

extension URL {
    init?(homeserverString: String) {
        var homeserver = homeserverString

        // If there's no scheme at all, the URLComponents initializer below will think it's a path with no hostname.
        if !homeserver.contains("//") {
            homeserver = "https://\(homeserver)"
        }

        var homeserverURLComponents = URLComponents(string: homeserver)
        homeserverURLComponents?.scheme = "https"

        guard let homeserverURL = homeserverURLComponents?.url else { return nil }
        self = homeserverURL
    }
}
