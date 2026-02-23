// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
internal enum L10n {

  internal enum Composer {
    /// Edit Message:
    internal static let editMessage = L10n.tr("Localizable", "composer.edit-message")
    /// New Message…
    internal static let newMessage = L10n.tr("Localizable", "composer.new-message")
    internal enum AccessibilityLabel {
      /// Cancel
      internal static let cancelEdit = L10n.tr("Localizable", "composer.accessibility-label.cancelEdit")
      /// Send
      internal static let send = L10n.tr("Localizable", "composer.accessibility-label.send")
      /// Send file
      internal static let sendFile = L10n.tr("Localizable", "composer.accessibility-label.send-file")
    }
  }

  internal enum Event {
    /// edited
    internal static let edited = L10n.tr("Localizable", "event.edited")
    /// Reason: %@
    internal static func reason(_ p1: Any) -> String {
      return L10n.tr("Localizable", "event.reason", String(describing: p1))
    }
    /// Unknown
    internal static let unknownRoomNameFallback = L10n.tr("Localizable", "event.unknown-room-name-fallback")
    /// Unknown
    internal static let unknownSenderFallback = L10n.tr("Localizable", "event.unknown-sender-fallback")
    internal enum ContextMenu {
      /// Add Reaction
      internal static let addReaction = L10n.tr("Localizable", "event.context-menu.add-reaction")
      /// Edit
      internal static let edit = L10n.tr("Localizable", "event.context-menu.edit")
      /// Remove
      internal static let remove = L10n.tr("Localizable", "event.context-menu.remove")
      /// Reply
      internal static let reply = L10n.tr("Localizable", "event.context-menu.reply")
    }
    internal enum Redaction {
      /// %@ removed %@'s message
      internal static func redactOther(_ p1: Any, _ p2: Any) -> String {
        return L10n.tr("Localizable", "event.redaction.redact-other", String(describing: p1), String(describing: p2))
      }
      /// Message removed by %@
      internal static func redactSelf(_ p1: Any) -> String {
        return L10n.tr("Localizable", "event.redaction.redact-self", String(describing: p1))
      }
    }
    internal enum RoomMember {
      /// %@ banned %@
      internal static func ban(_ p1: Any, _ p2: Any) -> String {
        return L10n.tr("Localizable", "event.room-member.ban", String(describing: p1), String(describing: p2))
      }
      /// %@ updated their profile picture
      internal static func changeAvatar(_ p1: Any) -> String {
        return L10n.tr("Localizable", "event.room-member.change-avatar", String(describing: p1))
      }
      /// %@ changed their display name to %@
      internal static func changeName(_ p1: Any, _ p2: Any) -> String {
        return L10n.tr("Localizable", "event.room-member.change-name", String(describing: p1), String(describing: p2))
      }
      /// %@ invited %@
      internal static func invited(_ p1: Any, _ p2: Any) -> String {
        return L10n.tr("Localizable", "event.room-member.invited", String(describing: p1), String(describing: p2))
      }
      /// %@ joined
      internal static func joined(_ p1: Any) -> String {
        return L10n.tr("Localizable", "event.room-member.joined", String(describing: p1))
      }
      /// %@ kicked %@
      internal static func kicked(_ p1: Any, _ p2: Any) -> String {
        return L10n.tr("Localizable", "event.room-member.kicked", String(describing: p1), String(describing: p2))
      }
      /// %@ left
      internal static func `left`(_ p1: Any) -> String {
        return L10n.tr("Localizable", "event.room-member.left", String(describing: p1))
      }
      /// %@ removed their profile picture
      internal static func removeAvatar(_ p1: Any) -> String {
        return L10n.tr("Localizable", "event.room-member.remove-avatar", String(describing: p1))
      }
      /// %@ set their profile picture
      internal static func setAvatar(_ p1: Any) -> String {
        return L10n.tr("Localizable", "event.room-member.set-avatar", String(describing: p1))
      }
      /// Unknown state event: %@
      internal static func unknownState(_ p1: Any) -> String {
        return L10n.tr("Localizable", "event.room-member.unknown-state", String(describing: p1))
      }
    }
    internal enum RoomName {
      /// %@ changed the room name from %@ to %@
      internal static func changeName(_ p1: Any, _ p2: Any, _ p3: Any) -> String {
        return L10n.tr("Localizable", "event.room-name.change-name", String(describing: p1), String(describing: p2), String(describing: p3))
      }
      /// %@ set the room name to %@
      internal static func setName(_ p1: Any, _ p2: Any) -> String {
        return L10n.tr("Localizable", "event.room-name.set-name", String(describing: p1), String(describing: p2))
      }
    }
    internal enum RoomPowerLevel {
      /// %@ changed the power level of %@ from %@ to %@
      internal static func changeOther(_ p1: Any, _ p2: Any, _ p3: Any, _ p4: Any) -> String {
        return L10n.tr("Localizable", "event.room-power-level.change-other", String(describing: p1), String(describing: p2), String(describing: p3), String(describing: p4))
      }
      /// %@ changed their power level from %@ to %@
      internal static func changeSelf(_ p1: Any, _ p2: Any, _ p3: Any) -> String {
        return L10n.tr("Localizable", "event.room-power-level.change-self", String(describing: p1), String(describing: p2), String(describing: p3))
      }
    }
    internal enum RoomTopic {
      /// %@ changed the topic to '%@'
      internal static func change(_ p1: Any, _ p2: Any) -> String {
        return L10n.tr("Localizable", "event.room-topic.change", String(describing: p1), String(describing: p2))
      }
    }
  }

  internal enum Loading {
    /// Reticulating splines
    internal static let _1 = L10n.tr("Localizable", "loading.1")
    /// Discomfrobulating messages
    internal static let _2 = L10n.tr("Localizable", "loading.2")
    /// Logging in
    internal static let _3 = L10n.tr("Localizable", "loading.3")
    /// Restoring session
    internal static let _4 = L10n.tr("Localizable", "loading.4")
    /// Cancel
    internal static let cancel = L10n.tr("Localizable", "loading.cancel")
  }

  internal enum Login {
    /// Back to Login
    internal static let failureBackToLogin = L10n.tr("Localizable", "login.failure-back-to-login")
    /// Don't have an account yet?
    internal static let openRegistrationPrompt = L10n.tr("Localizable", "login.open-registration-prompt")
    /// Registering for new accounts is not yet implemented.
    internal static let registerNotYetImplemented = L10n.tr("Localizable", "login.register-not-yet-implemented")
    /// Sign in
    internal static let signIn = L10n.tr("Localizable", "login.sign-in")
    /// Welcome to 
    internal static let welcomeHeader = L10n.tr("Localizable", "login.welcome-header")
    /// Sign in to your account to get started.
    internal static let welcomeMessage = L10n.tr("Localizable", "login.welcome-message")
    internal enum Form {
      /// Homeserver
      internal static let homeserver = L10n.tr("Localizable", "login.form.homeserver")
      /// Homeserver is optional if you're using matrix.org.
      internal static let homeserverOptionalExplanation = L10n.tr("Localizable", "login.form.homeserver-optional-explanation")
      /// Password
      internal static let password = L10n.tr("Localizable", "login.form.password")
      /// Username
      internal static let username = L10n.tr("Localizable", "login.form.username")
    }
  }

  internal enum NewConversation {
    /// Failed To Start Chat
    internal static let alertFailed = L10n.tr("Localizable", "new-conversation.alert-failed")
    /// Cancel
    internal static let cancel = L10n.tr("Localizable", "new-conversation.cancel")
    /// Contacts on Matrix
    internal static let contactsMatrix = L10n.tr("Localizable", "new-conversation.contacts-matrix")
    /// Start Chat
    internal static let createRoom = L10n.tr("Localizable", "new-conversation.create-room")
    /// Done
    internal static let done = L10n.tr("Localizable", "new-conversation.done")
    /// Edit
    internal static let edit = L10n.tr("Localizable", "new-conversation.edit")
    /// For example
    internal static let forExample = L10n.tr("Localizable", "new-conversation.for-example")
    /// Public Room
    internal static let publicRoom = L10n.tr("Localizable", "new-conversation.public-room")
    /// Room Name
    internal static let roomName = L10n.tr("Localizable", "new-conversation.room-name")
    /// New Chat
    internal static let titleChat = L10n.tr("Localizable", "new-conversation.title-chat")
    /// New Room
    internal static let titleRoom = L10n.tr("Localizable", "new-conversation.title-room")
    /// Matrix ID
    internal static let usernamePlaceholder = L10n.tr("Localizable", "new-conversation.username-placeholder")
    /// Matrix ID, Phone, or Email
    internal static let usernamePlaceholderExtended = L10n.tr("Localizable", "new-conversation.username-placeholder-extended")
  }

  internal enum ReactionPicker {
    /// Tap on an emoji to send that reaction.
    internal static let title = L10n.tr("Localizable", "reaction-picker.title")
  }

  internal enum RecentRooms {
    /// New Message
    internal static let newMessagePlaceholder = L10n.tr("Localizable", "recent-rooms.new-message-placeholder")
    internal enum AccessibilityLabel {
      /// DM with %@, %@ %@
      internal static func dm(_ p1: Any, _ p2: Any, _ p3: Any) -> String {
        return L10n.tr("Localizable", "recent-rooms.accessibility-label.dm", String(describing: p1), String(describing: p2), String(describing: p3))
      }
      /// New Conversation
      internal static let newConversation = L10n.tr("Localizable", "recent-rooms.accessibility-label.new-conversation")
      /// %u new messages
      internal static func newMessageBadge(_ p1: Int) -> String {
        return L10n.tr("Localizable", "recent-rooms.accessibility-label.new-message-badge", p1)
      }
      /// Room %@, %@ %@
      internal static func room(_ p1: Any, _ p2: Any, _ p3: Any) -> String {
        return L10n.tr("Localizable", "recent-rooms.accessibility-label.room", String(describing: p1), String(describing: p2), String(describing: p3))
      }
      /// Settings
      internal static let settings = L10n.tr("Localizable", "recent-rooms.accessibility-label.settings")
    }
    internal enum Leave {
      /// Are you sure you want to leave '%@'? This action cannot be undone.
      internal static func alertBody(_ p1: Any) -> String {
        return L10n.tr("Localizable", "recent-rooms.leave.alert-body", String(describing: p1))
      }
      /// Leave Room
      internal static let alertTitle = L10n.tr("Localizable", "recent-rooms.leave.alert-title")
    }
    internal enum PendingInvitations {
      /// Pending Invitations
      internal static let header = L10n.tr("Localizable", "recent-rooms.pending-invitations.header")
      internal enum Leave {
        /// Reject Invitation?
        internal static let alertTitle = L10n.tr("Localizable", "recent-rooms.pending-invitations.leave.alert-title")
      }
    }
    internal enum Rooms {
      /// Rooms
      internal static let header = L10n.tr("Localizable", "recent-rooms.rooms.header")
    }
  }

  internal enum Room {
    internal enum Attachment {
      /// Send attachment
      internal static let selectType = L10n.tr("Localizable", "room.attachment.select-type")
      /// Photo
      internal static let typePhoto = L10n.tr("Localizable", "room.attachment.type-photo")
    }
    internal enum Invitation {
      /// New Conversation
      internal static let fallbackTitle = L10n.tr("Localizable", "room.invitation.fallback-title")
      internal enum JoinAlert {
        /// Join
        internal static let joinButton = L10n.tr("Localizable", "room.invitation.join-alert.join-button")
        /// Accept invitation to join '%@'?
        internal static func message(_ p1: Any) -> String {
          return L10n.tr("Localizable", "room.invitation.join-alert.message", String(describing: p1))
        }
        /// Join Conversation?
        internal static let title = L10n.tr("Localizable", "room.invitation.join-alert.title")
      }
    }
    internal enum Remove {
      /// Remove
      internal static let action = L10n.tr("Localizable", "room.remove.action")
      /// Are you sure you want to remove this message?
      internal static let message = L10n.tr("Localizable", "room.remove.message")
      /// Remove?
      internal static let title = L10n.tr("Localizable", "room.remove.title")
    }
  }

  internal enum RoomPowerLevel {
    /// Admin
    internal static let admin = L10n.tr("Localizable", "room-power-level.admin")
    /// Custom (%d)
    internal static func custom(_ p1: Int) -> String {
      return L10n.tr("Localizable", "room-power-level.custom", p1)
    }
    /// Default
    internal static let `default` = L10n.tr("Localizable", "room-power-level.default")
    /// Moderator
    internal static let moderator = L10n.tr("Localizable", "room-power-level.moderator")
  }

  internal enum Settings {
    /// Accent Color
    internal static let accentColor = L10n.tr("Localizable", "settings.accent-color")
    /// App Icon
    internal static let appIcon = L10n.tr("Localizable", "settings.app-icon")
    /// Done
    internal static let dismiss = L10n.tr("Localizable", "settings.dismiss")
    /// Log Out
    internal static let logOut = L10n.tr("Localizable", "settings.log-out")
    /// Settings
    internal static let title = L10n.tr("Localizable", "settings.title")
  }

  internal enum SettingsIdentityServer {
    /// Closed Federation
    internal static let closedFederation = L10n.tr("Localizable", "settings-identity-server.closed-federation")
    /// At the moment, the identity servers are in a closed federation configuration. This means that there are only two identity servers (matrix.org, vector.im) and all data uploaded to one is copied to the other.
    internal static let closedFederationText = L10n.tr("Localizable", "settings-identity-server.closed-federation-text")
    /// Sync Contacts
    internal static let contactSync = L10n.tr("Localizable", "settings-identity-server.contact-sync")
    /// Continue
    internal static let `continue` = L10n.tr("Localizable", "settings-identity-server.continue")
    /// Data
    internal static let data = L10n.tr("Localizable", "settings-identity-server.data")
    /// Data & Privacy
    internal static let dataPrivacy = L10n.tr("Localizable", "settings-identity-server.data-privacy")
    /// By using the identity server, your email address and phone number will be sent to the identity server and will be linked to your Matrix ID (%@).
    internal static func dataText(_ p1: Any) -> String {
      return L10n.tr("Localizable", "settings-identity-server.data-text", String(describing: p1))
    }
    /// Learn More
    internal static let learnMore = L10n.tr("Localizable", "settings-identity-server.learn-more")
    /// Match
    internal static let match = L10n.tr("Localizable", "settings-identity-server.match")
    /// Any user can retrieve your Matrix ID by entering your email address or phone number, but cannot find your email address or phone number by entering your Matrix ID.
    internal static let matchText = L10n.tr("Localizable", "settings-identity-server.match-text")
    /// (Optional) Contact Sync
    internal static let optionalContactSync = L10n.tr("Localizable", "settings-identity-server.optional-contact-sync")
    /// When activating contact syncronization, Nio will periodically send the email addresses and phone numbers of all your contacts to the identity server to see if that contact has a linked Matrix ID. This contact information is never stored or shared with other parties by Nio.
    internal static let optionalContactSyncText = L10n.tr("Localizable", "settings-identity-server.optional-contact-sync-text")
    /// Please go to Settings and turn on the permissions.
    internal static let permissionAlertBody = L10n.tr("Localizable", "settings-identity-server.permission-alert-body")
    /// No permissions
    internal static let permissionAlertTitle = L10n.tr("Localizable", "settings-identity-server.permission-alert-title")
    /// Cancel
    internal static let permissionCancelButton = L10n.tr("Localizable", "settings-identity-server.permission-cancel-button")
    /// Settings
    internal static let permissionSettingsButton = L10n.tr("Localizable", "settings-identity-server.permission-settings-button")
    /// Identity Server
    internal static let title = L10n.tr("Localizable", "settings-identity-server.title")
    /// Enable Identity Server
    internal static let toggle = L10n.tr("Localizable", "settings-identity-server.toggle")
    /// Identity URL
    internal static let url = L10n.tr("Localizable", "settings-identity-server.url")
  }

  internal enum TypingIndicator {
    /// Several people are typing
    internal static let many = L10n.tr("Localizable", "typing-indicator.many")
    /// %@ is typing
    internal static func single(_ p1: Any) -> String {
      return L10n.tr("Localizable", "typing-indicator.single", String(describing: p1))
    }
    /// %@ and %@ are typing
    internal static func two(_ p1: Any, _ p2: Any) -> String {
      return L10n.tr("Localizable", "typing-indicator.two", String(describing: p1), String(describing: p2))
    }
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension L10n {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    let format = BundleToken.bundle.localizedString(forKey: key, value: nil, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
