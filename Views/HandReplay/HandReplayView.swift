import SwiftUI
import Foundation

struct Card: Identifiable {
    let id = UUID()
    let rank: String
    let suit: String
    
    var description: String {
        return rank + suit
    }
    
    // Parse a card string like "Ah" or "Td"
    init(from string: String) {
        self.rank = String(string.prefix(1))
        self.suit = String(string.suffix(1))
    }
}

struct HandReplayView: View {
    let hand: ParsedHandHistory
    @State private var currentStreetIndex = 0
    @State private var currentActionIndex = 0
    @State private var isPlaying = false
    @State private var potAmount: Double = 0
    @State private var playerStacks: [String: Double] = [:]
    @State private var foldedPlayers: Set<String> = []
    @State private var isHandComplete = false
    
    private let tableColor = Color(red: 45/255, green: 120/255, blue: 65/255)
    private let tableBorderColor = Color(red: 74/255, green: 54/255, blue: 38/255)
    
    private var hasMoreActions: Bool {
        guard currentStreetIndex < hand.raw.streets.count else { return false }
        let currentStreet = hand.raw.streets[currentStreetIndex]
        return currentActionIndex < currentStreet.actions.count || currentStreetIndex + 1 < hand.raw.streets.count
    }
    
    // This is the key change - accumulate all cards as the hand progresses
    private var allCommunityCards: [String] {
        var cards: [String] = []
        for i in 0...min(currentStreetIndex, hand.raw.streets.count - 1) {
            cards.append(contentsOf: hand.raw.streets[i].cards)
        }
        return cards
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(UIColor(red: 10/255, green: 10/255, blue: 15/255, alpha: 1.0))
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Controls - always at the top, with plenty of space below
                    HStack(spacing: 20) {
                        Button(action: startReplay) {
                            Text(isPlaying ? "Reset" : "Start")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(width: 100, height: 40)
                                .background(Color(red: 123/255, green: 255/255, blue: 99/255))
                                .cornerRadius(8)
                        }
                        
                        Button(action: nextAction) {
                            Text("Next")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(width: 100, height: 40)
                                .background(Color(red: 123/255, green: 255/255, blue: 99/255))
                                .opacity(isPlaying && hasMoreActions ? 1 : 0.5)
                                .cornerRadius(8)
                        }
                        .disabled(!isPlaying || !hasMoreActions)
                    }
                    .padding(.top, 24) // Plenty of space from the top
                    .zIndex(1) // Always on top
                    
                    Spacer(minLength: 16) // Space between buttons and table
                    
                    // Poker Table
                    ZStack {
                        // Table background
                        RoundedRectangle(cornerRadius: 25)
                            .fill(tableColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(tableBorderColor, lineWidth: 8)
                            )
                            .shadow(color: .black.opacity(0.5), radius: 10)
                        
                        // Stack Logo at the top
                        Text("STACK")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(0.3)
                            .offset(y: -geometry.size.height * 0.3)
                        
                        // Pot display with label
                        if potAmount > 0 {
                            VStack(spacing: 4) {
                                Text("Pot")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.9))
                                ChipView(amount: potAmount)
                            }
                            .offset(x: -geometry.size.width * 0.05, y: -geometry.size.height * 0.05)
                        }
                        
                        // Community Cards - moved slightly left
                        if currentStreetIndex >= 0 {
                            CommunityCardsView(cards: allCommunityCards)
                                .offset(x: -geometry.size.width * 0.05, y: geometry.size.height * 0.1)
                        }
                        
                        // Player Seats
                        ForEach(hand.raw.players, id: \.seat) { player in
                            PlayerSeatView(
                                player: player,
                                isFolded: foldedPlayers.contains(player.name),
                                isHero: player.isHero,
                                stack: playerStacks[player.name] ?? player.stack,
                                geometry: geometry,
                                allPlayers: hand.raw.players
                            )
                        }
                    }
                    .frame(height: geometry.size.height * 0.85)
                }
            }
        }
        .onAppear {
            initializeStacks()
        }
    }
    
    private func initializeStacks() {
        hand.raw.players.forEach { player in
            playerStacks[player.name] = player.stack
        }
    }
    
    private func startReplay() {
        currentStreetIndex = 0
        currentActionIndex = 0
        isPlaying = true
        isHandComplete = false
        potAmount = 0
        foldedPlayers.removeAll()
        initializeStacks()
    }
    
    private func nextAction() {
        guard !isHandComplete else { return }
        
        if currentStreetIndex < hand.raw.streets.count {
            let currentStreet = hand.raw.streets[currentStreetIndex]
            
            if currentActionIndex < currentStreet.actions.count {
                let action = currentStreet.actions[currentActionIndex]
                
                // Update game state based on action
                switch action.action.lowercased() {
                case "folds":
                    foldedPlayers.insert(action.playerName)
                case "bets", "raises", "calls":
                    if let stack = playerStacks[action.playerName] {
                        playerStacks[action.playerName] = stack - action.amount
                        potAmount += action.amount
                    }
                default:
                    break
                }
                
                currentActionIndex += 1
            } else if currentStreetIndex + 1 < hand.raw.streets.count {
                currentStreetIndex += 1
                currentActionIndex = 0
            } else {
                isHandComplete = true
            }
        } else {
            isHandComplete = true
        }
    }
}

struct CommunityCardsView: View {
    let cards: [String]
    
    var body: some View {
        // Simple horizontal layout, all cards side by side
        HStack(spacing: 4) {
            ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                CardView(card: Card(from: card))
                    .frame(width: 35, height: 50)
            }
        }
    }
}

struct CardView: View {
    let card: Card
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .shadow(radius: 1)
            
            VStack(spacing: 0) {
                Text(card.rank)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(card.suit.lowercased() == "h" || card.suit.lowercased() == "d" ? .red : .black)
                Text(suitSymbol(for: card.suit))
                    .font(.system(size: 14))
                    .foregroundColor(card.suit.lowercased() == "h" || card.suit.lowercased() == "d" ? .red : .black)
            }
        }
    }
    
    private func suitSymbol(for suit: String) -> String {
        switch suit.lowercased() {
        case "h": return "♥️"
        case "d": return "♦️"
        case "c": return "♣️"
        case "s": return "♠️"
        default: return suit
        }
    }
}

struct PlayerSeatView: View {
    let player: Player
    let isFolded: Bool
    let isHero: Bool
    let stack: Double
    let geometry: GeometryProxy
    let allPlayers: [Player]
    
    @State private var showCards: Bool = true
    
    var displayName: String {
        isHero ? "Hero" : (player.position ?? "")
    }
    
    private func getPosition() -> CGPoint {
        let width = geometry.size.width
        let height = geometry.size.height
        
        // Moved everything slightly left (0.5 -> 0.45 for center)
        // Evenly spread positions
        let positions = [
            CGPoint(x: width * 0.45, y: height * 0.75),  // 0: Hero (bottom center)
            CGPoint(x: width * 0.15, y: height * 0.75),  // 1: Bottom left (small blind)
            CGPoint(x: width * 0.15, y: height * 0.55),  // 2: Left bottom (big blind)
            CGPoint(x: width * 0.15, y: height * 0.35),  // 3: Left top (utg)
            CGPoint(x: width * 0.45, y: height * 0.2),   // 4: Top left (utg+1)
            CGPoint(x: width * 0.75, y: height * 0.2),   // 5: Top right (utg+2)
            CGPoint(x: width * 0.75, y: height * 0.35),  // 6: Right top (lojack)
            CGPoint(x: width * 0.75, y: height * 0.55),  // 7: Right bottom (hijack)
            CGPoint(x: width * 0.75, y: height * 0.75),  // 8: Bottom right (cutoff)
        ]
        
        if isHero {
            return positions[0]
        }
        
        let heroSeat = allPlayers.first(where: { $0.isHero })?.seat ?? 0
        var relativeSeat = player.seat - heroSeat
        if relativeSeat <= 0 {
            relativeSeat += allPlayers.count
        }
        
        let positionIndex = min(relativeSeat, positions.count - 1)
        return positions[positionIndex]
    }
    
    var body: some View {
        let position = getPosition()
        
        VStack(spacing: 4) {
            // Position indicator with better visibility
            Text(player.position ?? "")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.9))  // Increased opacity
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.3))  // Added background
                .cornerRadius(4)
            
            // Player name
            Text(player.name)
                .font(.system(size: 14, weight: isHero ? .bold : .regular))
                .foregroundColor(.white)
            
            // Stack amount
            ChipView(amount: stack)
                .frame(width: 40, height: 40)
            
            // Cards
            if let cards = player.cards, !cards.isEmpty {
                HStack(spacing: -5) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                        CardView(card: Card(from: card))
                            .frame(width: 30, height: 45)
                    }
                }
            }
        }
        .opacity(isFolded ? 0.5 : 1.0)
        .position(x: position.x, y: position.y)
    }
}

// Update ChipView to match mockup style
struct ChipView: View {
    let amount: Double
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 50, height: 50)
                .shadow(color: .black.opacity(0.3), radius: 2)
            Circle()
                .fill(Color.green.opacity(0.9))
                .frame(width: 46, height: 46)
            Text("$\(Int(amount))")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

struct ActionLogView: View {
    let hand: ParsedHandHistory
    let currentStreetIndex: Int
    let currentActionIndex: Int
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0...currentStreetIndex, id: \.self) { streetIndex in
                    let street = hand.raw.streets[streetIndex]
                    ForEach(0..<(streetIndex == currentStreetIndex ? currentActionIndex : street.actions.count), id: \.self) { actionIndex in
                        let action = street.actions[actionIndex]
                        Text("\(action.playerName) \(action.action) \(action.amount > 0 ? "$\(Int(action.amount))" : "")")
                            .foregroundColor(.white)
                    }
                }
            }
            .padding()
        }
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
}

// Update the main view's frame to ensure everything is centered
extension View {
    func centerInParent() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal)
    }
} 
