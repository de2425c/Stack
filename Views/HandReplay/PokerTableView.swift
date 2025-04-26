import SwiftUI

struct PokerTableView: View {
    let hand: ParsedHandHistory
    let currentStreetIndex: Int
    let currentActionIndex: Int
    
    var body: some View {
        ZStack {
            // Table background
            Circle()
                .fill(Color.green.opacity(0.8))
                .padding()
            
            // Players
            ForEach(hand.raw.players) { player in
                PlayerSpot(
                    player: player,
                    currentStreet: hand.raw.streets[currentStreetIndex],
                    currentActionIndex: currentActionIndex
                )
                .position(playerPosition(for: player.seat))
            }
            
            // Community cards
            if currentStreetIndex >= 0 {
                let visibleCards = hand.raw.streets[currentStreetIndex].cards
                HStack {
                    ForEach(visibleCards, id: \.self) { card in
                        Text(card)
                            .font(.title)
                            .padding(8)
                            .background(Color.white)
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    private func playerPosition(for seat: Int) -> CGPoint {
        // Calculate position based on seat number
        let radius: CGFloat = 150
        let angle = 2 * .pi * CGFloat(seat) / CGFloat(hand.raw.gameInfo.tableSize)
        return CGPoint(
            x: radius * cos(angle),
            y: radius * sin(angle)
        )
    }
}

struct PlayerSpot: View {
    let player: Player
    let currentStreet: Street
    let currentActionIndex: Int
    
    var body: some View {
        VStack {
            Text(player.name)
                .font(.headline)
            Text("$\(player.stack, specifier: "%.2f")")
                .font(.subheadline)
            if let cards = player.cards {
                Text(cards.joined(separator: " "))
                    .font(.caption)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
} 