//
//  AccountPreferencesSecurityView.swift
//  Nio
//
//  Created by Finn Behrens on 22.04.22.
//

import NioKit
import SwiftUI

struct AccountPreferencesSecurityView: View {
    @EnvironmentObject var account: NioAccount

    var body: some View {
        List {
            NavigationLink("Sessions") {
                AccountPreferencesSecurityDevicesView()
                    .environmentObject(account)
            }
        }
        .navigationTitle("Security")
    }
}

struct AccountPreferencesSecurityView_Previews: PreviewProvider {
    static var previews: some View {
        AccountPreferencesSecurityView()
    }
}
