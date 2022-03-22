//
//  RootView.swift
//  Nio
//
//  Created by Finn Behrens on 21.03.22.
//

import NioUIKit
import SwiftUI

struct RootView: View {
    var body: some View {
        RegisterContainer(callback: { token in
            print("token: \(token)")
        })
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
