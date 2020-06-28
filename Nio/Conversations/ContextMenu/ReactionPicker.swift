import SwiftUI

public struct ReactionPicker: View {
    @Environment(\.colorScheme) var colorScheme

    @State private var searchQuery = ""
    @State private var selectedCategory: EmojiCollection.Category = .smileysAndEmotion
    private var emoji = EmojiCollection()

    func headerView(for category: EmojiCollection.Category) -> some View {
        HStack {
            Text(category.name)
                .font(.headline)
                .padding(.vertical, 5)
            Spacer()
        }
    }

    var onSelect: (String) -> Void

    public init(onSelect: @escaping (String) -> Void) {
        self.onSelect = onSelect
    }

    let columns = [
        GridItem(.adaptive(minimum: 40), spacing: 20)
    ]

    public var body: some View {
        VStack {
            // Grab Handle Thingy
            Color.gray
                .frame(width: 40, height: 6)
                .cornerRadius(3.0)
                .opacity(0.8)
                .padding(.top)

            ZStack(alignment: .trailing) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField(L10n.ReactionPicker.search, text: $searchQuery)
                }
                .padding(8)
                .background(Color(colorScheme == .light ? #colorLiteral(red: 0.9332516193, green: 0.9333857894, blue: 0.941064477, alpha: 1) : #colorLiteral(red: 0.1882131398, green: 0.1960922778, blue: 0.2195765972, alpha: 1)).cornerRadius(8))
                .padding(.horizontal)

                if searchQuery != "" {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .foregroundColor(.gray)
                    // Adding standard padding with the extra padding we have on the text field above.
                    .padding(.trailing, 8)
                    .padding(.trailing)
                }
            }

            if searchQuery != "" {
                ScrollView {
                    LazyVGrid(columns: columns) {
                        ForEach(emoji.emoji(matching: searchQuery)) { emoji in
                            EmojiButtonView(emoji: emoji) { emoji in
                                onSelect(emoji)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            } else {
                Picker("", selection: $selectedCategory) {
                    ForEach(EmojiCollection.Category.allCases) { category in
                        category.iconImage
                            .tag(category)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                ScrollView {
                    LazyVGrid(columns: columns) {
//                                Section(header: headerView(for: selectedCategory)) {
                            ForEach(emoji.emoji(for: selectedCategory), id: \.self) { emoji in
                                EmojiButtonView(emoji: emoji) { emoji in
                                    onSelect(emoji)
                                }
                            }
//                                }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct EmojiButtonView: View {
    let emoji: EmojiCollection.Emoji
    let action: (String) -> Void

    var body: some View {
        Button {
            action(emoji.emoji)
        } label: {
            Text(emoji.emoji)
                .font(.system(size: 40))
        }
    }
}

struct ReactionPicker_Previews: PreviewProvider {
    static var previews: some View {
        ReactionPicker { _ in }
    }
}
