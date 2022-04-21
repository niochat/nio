//
//  MenuView.swift
//  Nio
//
//  Created by Finn Behrens on 30.03.22.
//

import MatrixCore
import SwiftUI

public struct MenuContainerView<Content: View>: View {
    @State var showMenu: Bool = false

    let content: () -> Content

    var dragGesture: some Gesture {
        DragGesture()
            .onEnded { vector in
                if vector.translation.width < -100 {
                    withAnimation {
                        self.showMenu = false
                    }
                }
            }
    }

    public init(content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                content()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(x: self.showMenu ? geometry.size.width * 0.8 : 0)
                    .disabled(self.showMenu)
                if self.showMenu {
                    MenuView()
                        .frame(width: geometry.size.width * 0.8, height: geometry.size.height)
                }
            }
            .gesture(dragGesture)
        }
        .toolbar {
            #if !os(macOS)
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
            #endif
        }
    }
}

struct MenuView: View {
    var body: some View {
        VStack(alignment: .leading) {
            MenuOwnAccountContainerView()
                .padding()

            // TODO: collapse view
            MenuAccountPickerContainerView()

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
            MenuView()

            MenuContainerView {
                Text("foo")
            }

            MenuContainerView {
                Text("foo")
            }
        }
    }
}
