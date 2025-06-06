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
    @State private var playerBets: [String: Double] = [:]
    @State private var showdownRevealed = false
    @State private var winningPlayers: Set<String> = []
    @State private var showPotDistribution = false
    
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
    
    private var isShowdown: Bool {
        guard currentStreetIndex == hand.raw.streets.count - 1 else { return false }
        let currentStreet = hand.raw.streets[currentStreetIndex]
        return currentActionIndex >= currentStreet.actions.count
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
                                .frame(width: 100, height: 30)
                                .background(Color(red: 123/255, green: 255/255, blue: 99/255))
                                .cornerRadius(8)
                        }
                        
                        Button(action: nextAction) {
                            Text("Next")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(width: 100, height: 30)
                                .background(Color(red: 123/255, green: 255/255, blue: 99/255))
                                .opacity(isPlaying && hasMoreActions ? 1 : 0.5)
                                .cornerRadius(8)
                        }
                        .disabled(!isPlaying || !hasMoreActions)
                    }
                    .padding(.top, 15) // Plenty of space from the top
                    .zIndex(1) // Always on top
                    
                    Spacer(minLength: 16) // Space between buttons and table
                    
                    // Poker Table
                    ZStack {
                        // Table background
                        Ellipse()
                            .fill(tableColor)
                            .overlay(
                                Ellipse()
                                    .stroke(tableBorderColor, lineWidth: 8)
                            )
                            .frame(width: geometry.size.width * 0.93, height: geometry.size.height * 0.83)
                            .position(x: geometry.size.width / 2, y: geometry.size.height * 0.35)
                            .shadow(color: .black.opacity(0.5), radius: 10)
                        
                        // Stack Logo - moved up
                        Text("STACK")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(0.3)
                            .offset(y: -geometry.size.height * 0.31) // right below top players

                        // Pot display - centered
                        if potAmount > 0 {
                            VStack(spacing: 4) {
                                Text("Pot")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.9))
                                ChipView(amount: potAmount)
                            }
                            .offset(y: -geometry.size.height * 0.22)
                        }

                        // Community Cards - centered, a bit below the pot
                        CommunityCardsView(cards: allCommunityCards)
                            .offset(y: -geometry.size.height * 0.1) // adjust as needed

                        // Player Seats
                        ForEach(hand.raw.players, id: \.seat) { player in
                            PlayerSeatView(
                                player: player,
                                isFolded: foldedPlayers.contains(player.name),
                                isHero: player.isHero,
                                stack: playerStacks[player.name] ?? player.stack,
                                geometry: geometry,
                                allPlayers: hand.raw.players,
                                betAmount: playerBets[player.name],
                                showdownRevealed: showdownRevealed,
                                isWinner: winningPlayers.contains(player.name),
                                showPotDistribution: showPotDistribution
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
        playerBets.removeAll()
        initializeStacks()
        
        // Set initial blind amounts
        if hand.raw.streets.count > 0 && hand.raw.streets[0].actions.count >= 2 {
            let preflop = hand.raw.streets[0]
            
            // Find small blind action
            if let sbAction = preflop.actions.first(where: { $0.action.lowercased().contains("small blind") }) {
                playerBets[sbAction.playerName] = sbAction.amount
                if let stack = playerStacks[sbAction.playerName] {
                    playerStacks[sbAction.playerName] = stack - sbAction.amount
                }
                potAmount += sbAction.amount
            }
            
            // Find big blind action
            if let bbAction = preflop.actions.first(where: { $0.action.lowercased().contains("big blind") }) {
                playerBets[bbAction.playerName] = bbAction.amount
                if let stack = playerStacks[bbAction.playerName] {
                    playerStacks[bbAction.playerName] = stack - bbAction.amount
                }
                potAmount += bbAction.amount
            }
        }
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
                    playerBets[action.playerName] = 0
                case "bets", "raises":
                    if let stack = playerStacks[action.playerName] {
                        playerStacks[action.playerName] = stack - action.amount
                        potAmount += action.amount
                        playerBets[action.playerName] = action.amount
                    }
                case "calls":
                    if let stack = playerStacks[action.playerName] {
                        playerStacks[action.playerName] = stack - action.amount
                        potAmount += action.amount
                        playerBets[action.playerName] = action.amount
                    }
                case "small blind", "big blind":
                    break
                default:
                    break
                }
                
                currentActionIndex += 1
            } else if currentStreetIndex + 1 < hand.raw.streets.count {
                currentStreetIndex += 1
                currentActionIndex = 0
                playerBets.removeAll()
            } else {
                // Handle showdown
                withAnimation(.easeInOut(duration: 0.5)) {
                    showdownRevealed = true
                }
                
                // Determine winners and distribute pot
                if let distribution = hand.raw.pot.distribution {
                    winningPlayers = Set(distribution.filter { $0.amount > 0 }.map { $0.playerName })
                    
                    // Animate pot distribution after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            showPotDistribution = true
                            
                            // Update player stacks with winnings
                            for potDist in distribution {
                                if let currentStack = playerStacks[potDist.playerName] {
                                    playerStacks[potDist.playerName] = currentStack + potDist.amount
                                }
                            }
                            potAmount = 0
                        }
                    }
                }
                
                isHandComplete = true
            }
        }
    }
}

struct CommunityCardsView: View {
    let cards: [String]

    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                // Flop
                if cards.count >= 3 {
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { idx in
                            if idx < cards.count {
                                CardView(card: Card(from: cards[idx]))
                                    .frame(width: 32, height: 46)
                            }
                        }
                    }
                }
                // Turn and River
                HStack(spacing: 8) {
                    if cards.count >= 4 {
                        CardView(card: Card(from: cards[3]))
                            .frame(width: 32, height: 46)
                    }
                    if cards.count >= 5 {
                        CardView(card: Card(from: cards[4]))
                            .frame(width: 32, height: 46)
                    }
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
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
    let betAmount: Double?
    let showdownRevealed: Bool
    let isWinner: Bool
    let showPotDistribution: Bool
    
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
            CGPoint(x: width * 0.5, y: height * 0.72),  // 0: Hero (bottom center)
            CGPoint(x: width * 0.12, y: height * 0.62),  // 1: Bottom left
            CGPoint(x: width * 0.08, y: height * 0.4),  // 2: Left middle
            CGPoint(x: width * 0.12, y: height * 0.2),  // 3: Left top
            CGPoint(x: width * 0.3, y: height * 0.05),   // 4: Top middle left
            CGPoint(x: width * 0.7, y: height * 0.05),   // 5: Top middle right
            CGPoint(x: width * 0.88, y: height * 0.2),  // 6: Right top
            CGPoint(x: width * 0.92, y: height * 0.4),  // 7: Right middle
            CGPoint(x: width * 0.88, y: height * 0.62),  // 8: Bottom right )
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
    
    private func getBetPosition() -> CGPoint {
        let width = geometry.size.width
        let height = geometry.size.height
        let centerX = width * 0.5
        let centerY = height * 0.35 // Approximate center of the table
        
        // Get the player's current position
        let pos = getPosition()
        
        // Special handling for hero's bet - place it to the right
        if isHero {
            return CGPoint(x: pos.x + 65, y: pos.y) // Increased spacing from 50 to 65
        }
        
        // Calculate vector from center to player
        let vectorX = pos.x - centerX
        let vectorY = pos.y - centerY
        
        // Normalize the vector
        let length = sqrt(vectorX * vectorX + vectorY * vectorY)
        let normalizedX = vectorX / length
        let normalizedY = vectorY / length
        
        // Increased bet distance for more spacing
        let betDistance: CGFloat = 55 // Increased from 40 to 55
        let betX = pos.x - (normalizedX * betDistance)
        let betY = pos.y - (normalizedY * betDistance)
        
        return CGPoint(x: betX, y: betY)
    }
    
    private var shouldShowCards: Bool {
        if isHero {
            return !isFolded && player.cards != nil
        } else {
            // Show villain's cards if:
            // 1. They haven't folded
            // 2. We're at showdown
            // 3. They have cards to show (either hole cards or final cards)
            // 4. They won or showed their cards
            return !isFolded && showdownRevealed && 
                   ((player.finalCards != nil && !player.finalCards!.isEmpty) || 
                    (isWinner && player.cards != nil))
        }
    }
    
    var body: some View {
        let position = getPosition()
        let betPosition = getBetPosition()
        
        let cardWidth: CGFloat = isHero ? 38 : 28
        let cardHeight: CGFloat = isHero ? 56 : 40
        let rectWidth: CGFloat = isHero ? 100 : 70
        let rectHeight: CGFloat = isHero ? 54 : 36
        let fontSize: CGFloat = isHero ? 17 : 13
        let stackFontSize: CGFloat = isHero ? 15 : 11
        let cardOffset: CGFloat = isHero ? -38 : -28
        
        ZStack {
            // Main content in a separate ZStack for proper layering
            ZStack {
                // Cards first (will be behind player info but above table)
                if shouldShowCards {
                    HStack(spacing: isHero ? 12 : 7) {
                        if let finalCards = player.finalCards, !finalCards.isEmpty {
                            // Show final cards if available (for mucked hands that were shown)
                            ForEach(Array(finalCards.enumerated()), id: \.offset) { index, card in
                                CardView(card: Card(from: card))
                                    .frame(width: cardWidth, height: cardHeight)
                            }
                        } else if let cards = player.cards, cards.count == 2 {
                            // Show hole cards
                            ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                                CardView(card: Card(from: card))
                                    .frame(width: cardWidth, height: cardHeight)
                            }
                        }
                    }
                    .offset(y: isHero ? -32 : cardOffset)
                    .zIndex(1)  // Above table, below player rectangle
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: showCards)
                } else if !isFolded {
                    // Back of cards
                    HStack(spacing: isHero ? 12 : 7) {
                        ForEach(0..<2, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: isHero ? 7 : 5)
                                .fill(Color.gray)
                                .frame(width: cardWidth, height: cardHeight)
                                .overlay(
                                    RoundedRectangle(cornerRadius: isHero ? 7 : 5)
                                        .stroke(Color.white, lineWidth: 1)
                                )
                        }
                    }
                    .offset(y: isHero ? -32 : cardOffset)
                    .zIndex(1)
                }
                
                // Player info rectangle on top
                VStack(spacing: isHero ? 8 : 4) {
                    Text(displayName)
                        .font(.system(size: fontSize, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(String(format: "$%.0f", stack))
                        .font(.system(size: stackFontSize))
                        .foregroundColor(isWinner ? .green : .white.opacity(0.9))
                }
                .frame(width: rectWidth, height: rectHeight)
                .background(
                    RoundedRectangle(cornerRadius: isHero ? 13 : 10)
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: isHero ? 13 : 10)
                                .stroke(isWinner ? Color.green : Color.white.opacity(0.7), lineWidth: isWinner ? 2 : 1)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                )
                .scaleEffect(isWinner && showPotDistribution ? 1.1 : 1.0)
                .animation(.spring(response: 0.3), value: isWinner && showPotDistribution)
                .zIndex(2)  // Highest z-index for player info
                .opacity(isFolded ? 0.5 : 1.0)
            }
            .position(x: position.x, y: position.y)
            
            // Bet amount in separate layer
            if let bet = betAmount, bet > 0 {
                ChipView(amount: bet)
                    .scaleEffect(0.8)
                    .position(x: betPosition.x, y: betPosition.y)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(3)  // Always on top
            }
        }
        .onAppear {
            showCards = true
        }
        .onChange(of: isFolded) { folded in
            withAnimation {
                showCards = !folded
            }
        }
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
