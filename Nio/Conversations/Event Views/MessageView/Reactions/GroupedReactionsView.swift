import SwiftUI
import MatrixSDK
import NioKit

struct GroupedReactionsView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @Environment(\.userId) var userId

    struct ViewModel {
        let reactions: [Reaction]

        fileprivate init(reactions: [Reaction]) {
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

    fileprivate func backgroundColor(for reactionGroup: ReactionGroup) -> Color {
        if reactionGroup.reactions.contains(where: { $0.sender == userId }) {
            return .accentColor
        }
        return .borderedMessageBackground
    }

    @ViewBuilder
    fileprivate func backgroundOverlay(for group: ReactionGroup) -> some View {
        if group.containsReaction(from: userId) {
            RoundedRectangle(cornerRadius: 30)
                .stroke(self.backgroundColor(for: group), lineWidth: 2)
        }
    }

    @State private var showReactionDetails = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(self.model.groupedReactions) { group in
                ReactionGroupView(
                    text: group.reaction,
                    count: group.count,
                    backgroundColor: self.backgroundColor(for: group)
                        .opacity(group.containsReaction(from: self.userId) ? 0.3 : 0.7)
                )
                .overlay(self.backgroundOverlay(for: group))
            }
        }
        .onLongPressGesture {
            self.showReactionDetails.toggle()
        }
        .sheet(isPresented: self.$showReactionDetails) {
            NavigationView {
                List {
                    ForEach(self.model.reactions) { reaction in
                        ReactionsListItemView(reaction: reaction)
                    }
                }
                    .navigationBarTitle("Reactions", displayMode: .inline)
            }
        }
    }
}

struct GroupedReactionsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            enumeratingColorSchemes {
                GroupedReactionsView(reactions: [
                    .init(id: "0", sender: "John", timestamp: Date(), reaction: "❤️"),
                    .init(id: "1", sender: "Jane", timestamp: Date(), reaction: "❤️"),
                    .init(id: "2", sender: "Jane", timestamp: Date(), reaction: "💜"),
                    .init(id: "3", sender: "John", timestamp: Date(), reaction: "🥳"),
                    .init(id: "4", sender: "John", timestamp: Date(), reaction: "🚀"),
                    .init(id: "5", sender: "John", timestamp: Date(), reaction: "🥳"),
                    .init(id: "6", sender: "John", timestamp: Date(), reaction: "🗑"),
                ])
                .padding()
            }
        }
        .environment(\.userId, "Jane")
        .accentColor(.purple)
        .previewLayout(.sizeThatFits)
    }
}
