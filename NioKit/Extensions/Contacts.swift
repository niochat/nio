//
//  Contacts.swift
//  Nio
//
//  Created by Stefan Hofman on 19/03/2021.
//  Copyright © 2021 Kilian Koeltzsch. All rights reserved.
//

import Foundation
import Contacts

public struct MatrixUser: Codable {
    let firstName: String
    let lastName: String
    let matrixID: String

    public init(firstName: String, lastName: String, matrixID: String) {
        self.firstName = firstName
        self.lastName = lastName
        self.matrixID = matrixID
    }
    public func getFirstName() -> String {
        return self.firstName
    }

    public func getLastName() -> String {
        return self.lastName
    }

    public func getMatrixID() -> String {
        return self.matrixID
    }
}

public class Contacts {

    public static func hasPermission() -> Bool {
        switch CNContactStore.authorizationStatus(for: CNEntityType.contacts) {
        case .authorized:
            return true
        case .notDetermined:
            return true
        default:
            return false
        }
    }

    public static func getAllContacts() -> [CNContact] {
        var contacts = [CNContact]()
        let store = CNContactStore()
        do {
            let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]
            let request = CNContactFetchRequest(keysToFetch: keys)
            try store.enumerateContacts(with: request) { (contact, _) in
                // Array containing all unified contacts from everywhere
                if contact.emailAddresses.count > 0 {
                    contacts.append(contact)
                }
            }
            return contacts
        } catch {
            return []
        }
    }
}
