import Foundation
import FirebaseFirestore

class HandStore: ObservableObject {
    @Published var savedHands: [ParsedHandHistory] = []
    private let db = Firestore.firestore()
    private let userId: String
    
    init(userId: String) {
        self.userId = userId
        loadSavedHands()
    }
    
    func saveHand(_ hand: ParsedHandHistory) async throws {
        let data = try JSONEncoder().encode(hand)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        
        try await db.collection("users")
            .document(userId)
            .collection("hands")
            .addDocument(data: [
                "hand": dict,
                "timestamp": FieldValue.serverTimestamp()
            ])
    }
    
    func loadSavedHands() {
        db.collection("users")
            .document(userId)
            .collection("hands")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching hands: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self?.savedHands = documents.compactMap { document in
                    guard let dict = document.data()["hand"] as? [String: Any],
                          let data = try? JSONSerialization.data(withJSONObject: dict),
                          let hand = try? JSONDecoder().decode(ParsedHandHistory.self, from: data)
                    else { return nil }
                    return hand
                }
            }
    }
} 