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
            // Grab-Handle Thingy
            Color.gray
                .frame(width: 40, height: 6)
                .cornerRadius(3.0)
                .opacity(0.8)
                .padding(.top)

            SearchField(placeholder: L10n.ReactionPicker.search, query: $searchQuery)

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
        Text(emoji.emoji)
            .font(.system(size: 40))
            .onTapGesture {
                action(emoji.emoji)
            }
    }
}

struct ReactionPicker_Previews: PreviewProvider {
    static var previews: some View {
        ReactionPicker { _ in }
    }
}
