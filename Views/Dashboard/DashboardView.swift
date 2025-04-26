import SwiftUI
import FirebaseFirestore

struct DashboardView: View {
    @StateObject private var handStore: HandStore
    @State private var selectedTab = 0
    private let tabs = ["Analytics", "Hands", "Sessions"]
    
    init(userId: String) {
        _handStore = StateObject(wrappedValue: HandStore(userId: userId))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(UIColor(red: 22/255, green: 23/255, blue: 26/255, alpha: 1.0))
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Tab Bar
                    HStack(spacing: 24) {
                        ForEach(0..<tabs.count, id: \.self) { index in
                            TabButton(
                                title: tabs[index],
                                isSelected: selectedTab == index
                            ) {
                                withAnimation {
                                    selectedTab = index
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Content
                    TabView(selection: $selectedTab) {
                        AnalyticsTab()
                            .tag(0)
                        
                        HandsTab(handStore: handStore)
                            .tag(1)
                        
                        SessionsTab()
                            .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "chart.line.uptrend.xyaxis") // or your app icon
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Image(systemName: "bell")
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                }
            }
        }
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : .gray)
                
                // Underline
                Rectangle()
                    .fill(Color(UIColor(red: 123/255, green: 255/255, blue: 99/255, alpha: 1.0)))
                    .frame(height: 2)
                    .opacity(isSelected ? 1 : 0)
            }
        }
    }
}

struct AnalyticsTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Bankroll Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Bankroll")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
                
                Text("$1,700.00")
                    .foregroundColor(.white)
                    .font(.system(size: 34, weight: .bold))
                
                HStack {
                    Image(systemName: "arrow.up")
                        .foregroundColor(.green)
                    Text("$200.00")
                        .foregroundColor(.green)
                    Text("Past month")
                        .foregroundColor(.gray)
                }
                .font(.system(size: 14))
            }
            .padding(.horizontal)
            .padding(.top)
            
            Text("Coming Soon")
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct HandsTab: View {
    @ObservedObject var handStore: HandStore
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(handStore.savedHands, id: \.raw.gameInfo.dealerSeat) { hand in
                    NavigationLink(destination: HandReplayView(hand: hand)) {
                        HandSummaryRow(hand: hand)
                            .background(Color(UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)))
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
    }
}

struct SessionsTab: View {
    var body: some View {
        VStack {
            Text("Coming Soon")
                .foregroundColor(.gray)
        }
    }
}

struct HandSummaryRow: View {
    let hand: ParsedHandHistory
    
    private var heroWon: Bool {
        guard let distribution = hand.raw.pot.distribution,
              let hero = hand.raw.players.first(where: { $0.isHero }) else {
            return false
        }
        return distribution.contains { potDist in
            potDist.playerName == hero.name && potDist.amount > 0
        }
    }
    
    private var roundedSmallBlind: Int {
        Int(floor(hand.raw.gameInfo.smallBlind))
    }
    
    private var roundedBigBlind: Int {
        Int(floor(hand.raw.gameInfo.bigBlind))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Blinds \(roundedSmallBlind)/\(roundedBigBlind)")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("Pot: $\(hand.raw.pot.amount, specifier: "%.0f")")
                    .foregroundColor(heroWon ? .green : .red)
                    .font(.headline)
            }
            
            if let hero = hand.raw.players.first(where: { $0.isHero }) {
                Text("Position: \(hero.position ?? "Unknown")")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                if let cards = hero.cards {
                    Text("Cards: \(cards.joined(separator: " "))")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
    }
} 