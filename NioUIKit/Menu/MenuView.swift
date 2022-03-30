//
//  MenuView.swift
//  Nio
//
//  Created by Finn Behrens on 30.03.22.
//

import MatrixCore
import SwiftUI

public struct MenuContainerView<Content: View>: View {
    @Binding var currentAccount: String

    @State var showMenu: Bool = false

    let content: () -> Content

    public init(currentAccount: Binding<String>, content: @escaping () -> Content) {
        _currentAccount = currentAccount
        self.content = content
    }

    public var body: some View {
        let drag = DragGesture()
            .onEnded { vector in
                if vector.translation.width < -100 {
                    withAnimation {
                        self.showMenu = false
                    }
                }
            }

        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                content()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(x: self.showMenu ? geometry.size.width * 0.8 : 0)
                    .disabled(self.showMenu)
                if self.showMenu {
                    MenuView(currentAccount: $currentAccount)
                        .frame(width: geometry.size.width * 0.8, height: geometry.size.height)
                }
            }
            .gesture(drag)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    withAnimation {
                        self.showMenu.toggle()
                    }
                }) {
                    Image(systemName: "line.horizontal.3")
                        .imageScale(.large)
                        .rotationEffect(self.showMenu ? .degrees(90) : .zero)
                }
            }
        }
    }
}

struct MenuView: View {
    @Binding var currentAccount: String

    var body: some View {
        VStack(alignment: .leading) {
            MenuOwnAccountContainerView(currentAccount: currentAccount)
                .padding()

            // TODO: collapse view
            MenuAccountPickerContainerView(currentAccount: $currentAccount)

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 32 / 255, green: 32 / 255, blue: 32 / 255))
    }
}

struct MenuView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MenuView(currentAccount: .constant("@preview:example.com"))

            MenuContainerView(currentAccount: .constant("@preview:example.com")) {
                Text("foo")
            }

            MenuContainerView(currentAccount: .constant("@preview:example.com")) {
                Text("foo")
            }
        }
    }
}
