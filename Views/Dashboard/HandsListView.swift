import SwiftUI

struct HandsListView: View {
    @StateObject private var handStore: HandStore

    init(userId: String) {
        _handStore = StateObject(wrappedValue: HandStore(userId: userId))
    }

    var body: some View {
        List {
            ForEach(handStore.savedHands.indices, id: \.self) { idx in
                HandRowView(hand: handStore.savedHands[idx], index: idx)
            }
        }
    }
}

// Minimal placeholder for HandRowView
struct HandRowView: View {
    let hand: ParsedHandHistory
    let index: Int

    var body: some View {
        VStack(alignment: .leading) {
            Text("Hand #\(index + 1)")
                .font(.headline)
            // You can add more details from `hand` here if you want
        }
    }
} 