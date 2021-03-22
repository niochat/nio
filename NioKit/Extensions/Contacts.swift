//
//  Contacts.swift
//  Nio
//
//  Created by Stefan Hofman on 19/03/2021.
//  Copyright © 2021 Kilian Koeltzsch. All rights reserved.
//

import Foundation
import Contacts

public class Contacts {
    public static func hasPermission() -> Bool {
        switch CNContactStore.authorizationStatus(for: CNEntityType.contacts) {
        case .authorized:
            return true
        case .notDetermined:
            return true
        default:
            print((Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "")
            CNContactStore().requestAccess(for: CNEntityType.contacts) { result, error in
                print(result)
                print(error)
            }
            return false
        }
    }
    
    public static func getContact() -> String {
        let store = CNContactStore()
        do {
            let predicate = CNContact.predicateForContacts(matchingName: "Hofman")
            let keysToFetch = [CNContactGivenNameKey, CNContactFamilyNameKey] as [CNKeyDescriptor]
            let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
            return "found"
        } catch {
            return "not found"
        }
    }
    
    public static func getAllContacts() -> [CNContact] {
        var contacts = [CNContact]()
        let store = CNContactStore()
        do {
            let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]
            let request = CNContactFetchRequest(keysToFetch: keys)
            try store.enumerateContacts(with: request) { (contact, stop) in
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
