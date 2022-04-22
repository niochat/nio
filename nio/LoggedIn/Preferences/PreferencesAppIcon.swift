//
//  PreferencesAppIcon.swift
//  Nio
//
//  Created by Finn Behrens on 22.04.22.
//

import NioKit
import SwiftUI

struct PreferencesAppIcon: View {
    var application = UIApplication.shared

    var body: some View {
        List(PreferencesAppIcon.list, id: \.self) { name in
            Button {
                NioAccountStore.logger.debug("Setting App Icon to \(name)")
                let icon = name == "Nio" ? nil : name
                application.setAlternateIconName(icon) { error in
                    print(error as Any)
                }
            } label: {
                HStack {
                    Label {
                        Text(name)
                            .padding()
                    } icon: {
                        Image("App Icons/\(name)")
                            .cornerRadius(12.5)
                            .padding([.leading, .trailing])
                    }
                    Spacer(minLength: 0)
                    if application.alternateIconName == "App Icons/\(name)" {
                        Image(systemName: "checkmark.cicle.fill")
                    }
                }
            }
        }
        .navigationTitle("App Icon")
    }

    static let list = [
        "Nio",
        "Sketch",
        "Six Colors Dark",
        "Six Colors Light",
    ]
}

struct PreferencesAppIcon_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesAppIcon()
    }
}
