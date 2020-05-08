// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command
// swiftlint:disable file_length

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name
internal enum L10n {

  internal enum Composer {
    /// Edit Message:
    internal static let editMessage = L10n.tr("Localizable", "composer.edit-message")
    /// New Message...
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
    internal static func reason(_ p1: String) -> String {
      return L10n.tr("Localizable", "event.reason", p1)
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
      internal static func redactOther(_ p1: String, _ p2: String) -> String {
        return L10n.tr("Localizable", "event.redaction.redact-other", p1, p2)
      }
      /// Message removed by %@
      internal static func redactSelf(_ p1: String) -> String {
        return L10n.tr("Localizable", "event.redaction.redact-self", p1)
      }
    }
    internal enum RoomMember {
      /// %@ banned %@
      internal static func ban(_ p1: String, _ p2: String) -> String {
        return L10n.tr("Localizable", "event.room-member.ban", p1, p2)
      }
      /// %@ updated their profile picture
      internal static func changeAvatar(_ p1: String) -> String {
        return L10n.tr("Localizable", "event.room-member.change-avatar", p1)
      }
      /// %@ changed their display name to %@
      internal static func changeName(_ p1: String, _ p2: String) -> String {
        return L10n.tr("Localizable", "event.room-member.change-name", p1, p2)
      }
      /// %@ invited %@
      internal static func invited(_ p1: String, _ p2: String) -> String {
        return L10n.tr("Localizable", "event.room-member.invited", p1, p2)
      }
      /// %@ joined
      internal static func joined(_ p1: String) -> String {
        return L10n.tr("Localizable", "event.room-member.joined", p1)
      }
      /// %@ kicked %@
      internal static func kicked(_ p1: String, _ p2: String) -> String {
        return L10n.tr("Localizable", "event.room-member.kicked", p1, p2)
      }
      /// %@ left
      internal static func `left`(_ p1: String) -> String {
        return L10n.tr("Localizable", "event.room-member.left", p1)
      }
      /// %@ removed their profile picture
      internal static func removeAvatar(_ p1: String) -> String {
        return L10n.tr("Localizable", "event.room-member.remove-avatar", p1)
      }
      /// %@ set their profile picture
      internal static func setAvatar(_ p1: String) -> String {
        return L10n.tr("Localizable", "event.room-member.set-avatar", p1)
      }
      /// Unknown state event: %@
      internal static func unknownState(_ p1: String) -> String {
        return L10n.tr("Localizable", "event.room-member.unknown-state", p1)
      }
    }
    internal enum RoomName {
      /// %@ changed the room name from %@ to %@
      internal static func changeName(_ p1: String, _ p2: String, _ p3: String) -> String {
        return L10n.tr("Localizable", "event.room-name.change-name", p1, p2, p3)
      }
      /// %@ set the room name to %@
      internal static func setName(_ p1: String, _ p2: String) -> String {
        return L10n.tr("Localizable", "event.room-name.set-name", p1, p2)
      }
    }
    internal enum RoomPowerLevel {
      /// %@ changed the power level of %@ from %@ to %@
      internal static func changeOther(_ p1: String, _ p2: String, _ p3: String, _ p4: String) -> String {
        return L10n.tr("Localizable", "event.room-power-level.change-other", p1, p2, p3, p4)
      }
      /// %@ changed their power level from %@ to %@
      internal static func changeSelf(_ p1: String, _ p2: String, _ p3: String) -> String {
        return L10n.tr("Localizable", "event.room-power-level.change-self", p1, p2, p3)
      }
    }
    internal enum RoomTopic {
      /// %@ changed the topic to '%@'
      internal static func change(_ p1: String, _ p2: String) -> String {
        return L10n.tr("Localizable", "event.room-topic.change", p1, p2)
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

  internal enum ReactionPicker {
    /// Tap on an emoji to send that reaction.
    internal static let title = L10n.tr("Localizable", "reaction-picker.title")
  }

  internal enum RecentRooms {
    /// New Message
    internal static let newMessagePlaceholder = L10n.tr("Localizable", "recent-rooms.new-message-placeholder")
    internal enum AccessibilityLabel {
      /// DM with %@, %@ %@
      internal static func dm(_ p1: String, _ p2: String, _ p3: String) -> String {
        return L10n.tr("Localizable", "recent-rooms.accessibility-label.dm", p1, p2, p3)
      }
      /// New Conversation
      internal static let newConversation = L10n.tr("Localizable", "recent-rooms.accessibility-label.new-conversation")
      /// %u new messages
      internal static func newMessageBadge(_ p1: Int) -> String {
        return L10n.tr("Localizable", "recent-rooms.accessibility-label.new-message-badge", p1)
      }
      /// Room %@, %@ %@
      internal static func room(_ p1: String, _ p2: String, _ p3: String) -> String {
        return L10n.tr("Localizable", "recent-rooms.accessibility-label.room", p1, p2, p3)
      }
      /// Settings
      internal static let settings = L10n.tr("Localizable", "recent-rooms.accessibility-label.settings")
    }
    internal enum Leave {
      /// Are you sure you want to leave '%@'? This action cannot be undone.
      internal static func alertBody(_ p1: String) -> String {
        return L10n.tr("Localizable", "recent-rooms.leave.alert-body", p1)
      }
      /// Leave Room
      internal static let alertTitle = L10n.tr("Localizable", "recent-rooms.leave.alert-title")
    }
  }

  internal enum Room {
    /// Not yet implemented
    internal static let attachmentPlaceholder = L10n.tr("Localizable", "room.attachment-placeholder")
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
    /// Log Out
    internal static let logOut = L10n.tr("Localizable", "settings.log-out")
    /// Settings
    internal static let title = L10n.tr("Localizable", "settings.title")
  }

  internal enum TypingIndicator {
    /// Several people are typing...
    internal static let many = L10n.tr("Localizable", "typing-indicator.many")
    /// %@ are typing...
    internal static func multiple(_ p1: String) -> String {
      return L10n.tr("Localizable", "typing-indicator.multiple", p1)
    }
    /// %@ is typing...
    internal static func single(_ p1: String) -> String {
      return L10n.tr("Localizable", "typing-indicator.single", p1)
    }
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name

// MARK: - Implementation Details

extension L10n {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    // swiftlint:disable:next nslocalizedstring_key
    let format = NSLocalizedString(key, tableName: table, bundle: Bundle(for: BundleToken.self), comment: "")
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

private final class BundleToken {}
