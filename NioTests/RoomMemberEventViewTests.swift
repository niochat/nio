import XCTest
import SwiftMatrixSDK
@testable import Nio

class RoomMemberEventViewTests: XCTestCase {
    typealias Model = RoomMemberEventView.ViewModel

    func testInviteEvent() {
        let inviteEvent = Model(
            sender: "Jane",
            current: .init(
                displayName: "John",
                avatarURL: nil,
                membership: "invite",
                reason: nil),
            previous: nil
        )
        XCTAssertEqual(inviteEvent.text, "Jane invited John")
    }

    // Disabled for now, see testKickEvent below.
    //swiftlint:disable:next identifier_name
    func _testWithdrawInviteEvent() {
        let withdrawInviteEvent = Model(
            sender: "Jane",
            current: .init(
                displayName: "John",
                avatarURL: nil,
                membership: "leave",
                reason: nil),
            previous: .init(
                displayName: "John",
                avatarURL: nil,
                membership: "invite",
                reason: nil)
        )
        XCTAssertEqual(withdrawInviteEvent.text, "Jane withdrew John's invitation.")
    }

    func testLeaveEvent() {
        let leaveEvent = Model(
            sender: "Jane",
            current: .init(
                displayName: "Jane",
                avatarURL: nil,
                membership: "leave",
                reason: nil),
            previous: nil
        )
        XCTAssertEqual(leaveEvent.text, "Jane left")
    }

    func testJoinEvent() {
        let joinEvent = Model(
            sender: "Jane",
            current: .init(
                displayName: "Jane",
                avatarURL: nil,
                membership: "join",
                reason: nil),
            previous: nil
        )
        XCTAssertEqual(joinEvent.text, "Jane joined")
    }

    // Disabled for now, since it can't be implemented until usernames are correctly handled.
    // Otherwise I'd show every leave event as a kick event 🤦‍♀️
    //swiftlint:disable:next identifier_name
    func _testKickEvent() throws {
        let kickEvent = Model(
            sender: "Jane",
            current: .init(
                displayName: "John",
                avatarURL: nil,
                membership: "leave",
                reason: nil),
            previous: nil)
        XCTAssertEqual(kickEvent.text, "Jane kicked John")
    }

    func testNameChangeEvent() {
        let nameChangeEvent = Model(
            sender: "Jane sender",
            current: .init(
                displayName: "Jane Doe",
                avatarURL: nil,
                membership: "join",
                reason: nil),
            previous: .init(
                displayName: "Jane",
                avatarURL: nil,
                membership: "join",
                reason: nil))
        XCTAssertEqual(nameChangeEvent.text, "Jane changed their display name to Jane Doe")
    }

    func testSetAvatarEvent() {
        let setAvatarEvent = Model(
            sender: "Jane sender",
            current: .init(
                displayName: "Jane",
                avatarURL: MXURL(mxContentURI: "mxc://uri"),
                membership: "join",
                reason: nil),
            previous: .init(
                displayName: "Jane",
                avatarURL: nil,
                membership: "join",
                reason: nil))
        XCTAssertEqual(setAvatarEvent.text, "Jane set their profile picture")
    }

    func testUpdateAvatarEvent() {
        let updateAvatarEvent = Model(
            sender: "Jane sender",
            current: .init(
                displayName: "Jane",
                avatarURL: MXURL(mxContentURI: "mxc://newuri"),
                membership: "join",
                reason: nil),
            previous: .init(
                displayName: "Jane",
                avatarURL: MXURL(mxContentURI: "mxc://olduri"),
                membership: "join",
                reason: nil))
        XCTAssertEqual(updateAvatarEvent.text, "Jane updated their profile picture")
    }

    func testRemoveAvatarEvent() {
        let removeAvatarEvent = Model(
            sender: "Jane sender",
            current: .init(
                displayName: "Jane",
                avatarURL: nil,
                membership: "join",
                reason: nil),
            previous: .init(
                displayName: "Jane",
                avatarURL: MXURL(mxContentURI: "mxc://olduri"),
                membership: "join",
                reason: nil))
        XCTAssertEqual(removeAvatarEvent.text, "Jane removed their profile picture")
    }
}
