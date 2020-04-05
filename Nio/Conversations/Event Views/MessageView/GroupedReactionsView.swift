import SwiftUI
import SwiftMatrixSDK

struct Reaction: Identifiable {
    let sender: String
    let timestamp: Date
    let reaction: String

    var id: Int {
        timestamp.hashValue
            ^ sender.hashValue
            ^ reaction.hashValue
    }
}

private struct ReactionGroup: Identifiable {
    let reaction: String
    let count: Int
    let reactions: [Reaction]

    var id: String {
        reaction
    }
}

struct GroupedReactionsView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @Environment(\.userId) var userId

    struct ViewModel {
        var reactions: [Reaction]

        init(reactions: [Reaction]) {
            self.reactions = reactions
        }

        fileprivate var groupedReactions: [ReactionGroup] {
            var reactionCounts: [String: Int] = [:]
            for reaction in reactions {
                reactionCounts[reaction.reaction, default: 0] += 1
            }
            // Sort reactions primarily by count, but emoji second, meaning those
            // reactions with the highest counts will come first, but if two
            // reactions have the same count, they'll be sorted via string sorting.
            // That way we get stable sorting which won't jump around on view
            // updates.
            // TODO: It would probably make even more sense to sort this by count
            // and then by the reaction event timestamps so that later reactions
            // are always added to the end of the list.
            let groups = reactionCounts.sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            return groups.map { (reaction, count) -> ReactionGroup in
                let fittingReactions = reactions.filter { $0.reaction == reaction }
                return ReactionGroup(reaction: reaction,
                                     count: count,
                                     reactions: fittingReactions)
            }
        }
    }

    var model: ViewModel

    init(reactions: [Reaction]) {
        self.model = ViewModel(reactions: reactions)
    }

    fileprivate func textColor(for reactionGroup: ReactionGroup) -> Color {
        if reactionGroup.reactions.contains(where: { $0.sender == userId }) {
            return .white
        }
        return .primary
    }

    fileprivate func backgroundColor(for reactionGroup: ReactionGroup) -> Color {
        if reactionGroup.reactions.contains(where: { $0.sender == userId }) {
            return .accentColor
        }
        return .borderedMessageBackground
    }

    fileprivate func backgroundGradient(for reactionGroup: ReactionGroup) -> LinearGradient {
        let color: Color = backgroundColor(for: reactionGroup)
        let colors: [Color]
        if colorScheme == .dark {
            colors = [color.opacity(1.0), color.opacity(0.85)]
        } else {
            colors = [color.opacity(0.85), color.opacity(1.0)]
        }
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @State private var showReactionDetails = false

    var body: some View {
        Group {
            if model.reactions.isEmpty {
                EmptyView()
            } else {
                HStack(spacing: 3) {
                    ForEach(model.groupedReactions) { group in
                        HStack(spacing: 1) {
                            Text(group.reaction)
                                .font(.headline)
                            Text(String(group.count))
                                .foregroundColor(self.textColor(for: group))
                                .font(.callout)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(RoundedRectangle(cornerRadius: 10)
                        .fill(self.backgroundGradient(for: group)))
                    }
                }
                .onLongPressGesture {
                    self.showReactionDetails.toggle()
                }
                .sheet(isPresented: $showReactionDetails) {
                    NavigationView {
                        List(self.model.reactions) { reaction in
                            HStack {
                                Text(reaction.reaction)
                                Text(reaction.sender)
                                Spacer()
                                Text(Formatter.string(for: reaction.timestamp, dateStyle: .short, timeStyle: .short))
                                    .foregroundColor(.gray)
                                    .font(.footnote)
                            }
                        }
                        .navigationBarTitle("Reactions", displayMode: .inline)
                    }
                }
            }
        }
    }
}

struct GroupedReactionsView_Previews: PreviewProvider {
    static var previews: some View {
        GroupedReactionsView(reactions: [
            .init(sender: "John", timestamp: Date(), reaction: "❤️"),
            .init(sender: "Jane", timestamp: Date(), reaction: "❤️"),
            .init(sender: "John", timestamp: Date(), reaction: "🥳"),
            .init(sender: "John", timestamp: Date(), reaction: "🚀"),
            .init(sender: "John", timestamp: Date(), reaction: "🥳"),
            .init(sender: "John", timestamp: Date(), reaction: "🗑"),
        ])
        .environment(\.userId, "Jane")
        .accentColor(.purple)
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
