//
//  AcknowledgmentsList.swift
//  Nio
//
//  Created by Finn Behrens on 22.04.22.
//

import AcknowList
import SwiftUI

struct AcknowledgmentsList: View {
    public var acknowledgements: [Acknow] = []

    public init(acknowledgements: [Acknow]) {
        self.acknowledgements = acknowledgements
    }

    public init(plistPath: String) {
        let parser = AcknowParser(plistPath: plistPath)

        self.init(acknowledgements: parser.parseAcknowledgements())
    }

    public init(plistName: String) {
        let path = Bundle.main.path(forResource: plistName, ofType: "plist") ?? ""
        self.init(plistPath: path)
    }

    var body: some View {
        List(acknowledgements) { acknowledgement in
            NavigationLink(destination: AcknowSwiftUIView(acknowledgement: acknowledgement)) {
                HStack {
                    Text(acknowledgement.title)
                    /* if let license = acknowledgement.license {
                         Spacer(minLength: 5)
                         Text(license)
                             .foregroundColor(.gray)
                             .font(.subheadline)
                     } */
                }
            }
        }
    }
}

struct AcknowledgmentsList_Previews: PreviewProvider {
    static var previews: some View {
        AcknowledgmentsList(acknowledgements: [Acknow(title: "Foo", text: "Foo Bar Lore Ipsum")])
    }
}
