import SwiftUI

struct LoginFormTextField: View {
    @Environment(\.colorScheme) var colorScheme

    var placeholder: String
    @Binding var text: String
    var onEditingChanged: ((Bool) -> Void)?

    var isSecure = false

    var buttonIcon: String?
    var buttonAction: (() -> Void)?

    var body: some View {
        ZStack {
            Capsule(style: .continuous)
                .foregroundColor(colorScheme == .light ? Color(#colorLiteral(red: 0.9395676295, green: 0.9395676295, blue: 0.9395676295, alpha: 1)) : Color(#colorLiteral(red: 0.2293992357, green: 0.2293992357, blue: 0.2293992357, alpha: 1)))
                .frame(height: 50)
            if isSecure {
                SecureField(placeholder, text: $text)
                    .padding()
                    .textContentType(.password)
            } else {
                HStack {
                    TextField(placeholder, text: $text, onEditingChanged: onEditingChanged ?? { _ in })
                        .padding()
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    if buttonIcon != nil && buttonAction != nil {
                        Button(action: {
                            self.buttonAction!()
                        }, label: {
                            Image(systemName: buttonIcon!)
                        })
                        .padding()
                    }
                }
            }
        }
        .frame(maxWidth: 400)
    }
}

struct LoginFormTextField_Previews: PreviewProvider {
    static var previews: some View {
        LoginFormTextField(placeholder: "Username", text: .constant(""))
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
