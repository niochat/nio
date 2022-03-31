//
//  ProfileSettingsSecurityContainerView.swift
//  Nio
//
//  Created by Finn Behrens on 31.03.22.
//

import MatrixCore
import SwiftUI

struct ProfileSettingsSecurityContainerView: View {
    @EnvironmentObject var account: MatrixAccount

    var body: some View {
        List {
            NavigationLink("Sessions") {
                ProfileSettingsSecurityDevicesContainerView()
                    .environmentObject(account)
            }
        }
        .navigationTitle("Security")
    }
}

struct ProfileSettingsSecurityContainerView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSettingsSecurityContainerView()
    }
}
