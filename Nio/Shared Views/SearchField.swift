import SwiftUI

struct SearchField: View {
    @Environment(\.colorScheme) var colorScheme
    let placeholder: String
    @Binding var query: String

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField(self.placeholder, text: $query)
            }
            .padding(8)
            .background(Color(colorScheme == .light ? #colorLiteral(red: 0.9332516193, green: 0.9333857894, blue: 0.941064477, alpha: 1) : #colorLiteral(red: 0.1882131398, green: 0.1960922778, blue: 0.2195765972, alpha: 1)).cornerRadius(8))
            .padding(.horizontal)

            if query != "" {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .foregroundColor(.gray)
                // Adding standard padding with the extra padding we have on the text field above.
                .padding(.trailing, 8)
                .padding(.trailing)
            }
        }
    }
}

struct SearchField_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            enumeratingColorSchemes {
                VStack {
                    SearchField(placeholder: "Search...", query: .constant(""))
                        .padding()
                    SearchField(placeholder: "", query: .constant("foobar"))
                        .padding([.bottom, .horizontal])
                }
            }
        }
        .previewLayout(.sizeThatFits)
    }
}
