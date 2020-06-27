import SwiftUI

public struct ReactionPicker: View {
    @State private var searchQuery = ""
    @State private var selectedCategory: Emoji.Category = Emoji.categories[0]

    func headerView(for category: Emoji.Category) -> some View {
        HStack {
            Text(category.name)
                .font(.headline)
                .padding(.leading)
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
        NavigationView {
            VStack {
                TextField(L10n.ReactionPicker.search, text: $searchQuery)
                    .padding()
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                if searchQuery != "" {
                    ScrollView {
                        LazyVGrid(columns: columns) {
                            ForEach(Emoji.emoji(forQuery: searchQuery), id: \.self) { emoji in
                                EmojiButtonView(emoji: emoji) { emoji in
                                    onSelect(emoji)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                } else {
                    Picker("", selection: $selectedCategory) {
                        ForEach(Emoji.categories) { category in
                            Text(category.icon).tag(category)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)

                    ScrollView {
                        LazyVGrid(columns: columns) {
                            Section(header: headerView(for: selectedCategory)) {
                                ForEach(Emoji.emoji(forCategory: selectedCategory.id), id: \.self) { emoji in
                                    EmojiButtonView(emoji: emoji) { emoji in
                                        onSelect(emoji)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationBarTitle(Text(L10n.ReactionPicker.navigationTitle))
        }
    }
}

struct EmojiButtonView: View {
    let emoji: String
    let action: (String) -> Void

    var body: some View {
        Button {
            action(emoji)
        } label: {
            Text(emoji)
                .font(.system(size: 40))
        }
    }
}

struct ReactionPicker_Previews: PreviewProvider {
    static var previews: some View {
        ReactionPicker { _ in }
    }
}
