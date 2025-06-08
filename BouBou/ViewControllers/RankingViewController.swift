//
//  RankingViewController.swift
//  BouBou
//
//  Created by Hongrui Wu  on 5/25/25.
//

import UIKit
import Firebase
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

class RankingViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    var allSends: [SendRecord] = []
    // Refresh control for pull to refresh
    let refreshControl = UIRefreshControl()


    @IBOutlet weak var tableView: UITableView!
    
    var rankingData: [(rank: Int, name: String, score: Int)] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = self
        tableView.delegate = self
        
        // Add refresh control
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
        // Fetch leaderboard data on load
        fetchSharedSends()
    }
    
    /// Called when user pulls to refresh the leaderboard.
    /// Triggers re-fetching of shared sends.
    @objc func handleRefresh() {
        print("🔄 Pull to refresh triggered.")
        
        // Re-fetch leaderboard data
        fetchSharedSends()
        
        // End refreshing after slight delay (optional smoother UX)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refreshControl.endRefreshing()
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rankingData.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RankingCell", for: indexPath) as! RankingTableViewCell
        let item = rankingData[indexPath.row]
        cell.rankLabel.text = "\(item.rank)"
        cell.nameLabel.text = item.name
        cell.scoreLabel.text = "\(item.score) pts"
        cell.avatarImageView.image = UIImage(systemName: "person.circle")
        return cell
    }
    
    /// Fetches all shared sends (isShared == true) from Firebase Firestore
    /// and populates the `allSends` array with SendRecord instances.
    /// After fetching, it will trigger leaderboard calculation and table reload.
    func fetchSharedSends() {
        let db = Firestore.firestore()
        
        // Only get isShared == true (public sends for World Leaderboard)
        db.collection("sends")
            .whereField("isShared", isEqualTo: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Failed to fetch sends: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ No documents found.")
                    return
                }
                
                // Clear previous sends
                self.allSends.removeAll()
                
                // Convert each document into a SendRecord and add to allSends
                for document in documents {
                    let data = document.data()
                    let sendRecord = SendRecord(documentID: document.documentID, dict: data)
                    self.allSends.append(sendRecord)
                }
                
                print("✅ Fetched \(self.allSends.count) shared sends.")
                
                // Proceed to calculate leaderboard and refresh table
                self.calculateLeaderboardAndRefresh()
            }
    }

    
    /// Calculates the score for a given SendRecord based on grade, status, and attempts.
    /// The higher the grade, better status, and fewer attempts → the higher the score.
    ///
    /// Formula:
    /// score = baseScore * statusMultiplier * attemptsPenalty
    ///
    /// - BaseScore: V grade number * 10
    /// - StatusMultiplier:
    ///     Onsight → 5, Flash → 4, Send → 3, Projecting/Other → 0
    /// - AttemptPenalty:
    ///     1 → 10, 2 → 9, ..., 10 → 1, "10+" → 1
    ///
    /// - Parameter send: The SendRecord object representing a climbing send.
    /// - Returns: An integer score representing the value of this send.
    func calculateScore(for send: SendRecord) -> Int {
        
        // 1️⃣ Calculate BaseScore from grade (e.g., "V5" → 50 points)
        let gradeNumber = Int(send.grade.replacingOccurrences(of: "V", with: "")) ?? 0
        let baseScore = gradeNumber * 10
        
        // 2️⃣ Calculate StatusMultiplier
        let statusMultiplier: Int
        switch send.status {
        case "Onsight":
            statusMultiplier = 5
        case "Flash":
            statusMultiplier = 4
        case "Send":
            statusMultiplier = 3
        default:
            // Projecting or unknown status → 0 points, not counted in leaderboard
            statusMultiplier = 0
        }
        
        // 3️⃣ Calculate AttemptPenalty (fewer attempts → higher multiplier)
        let attemptsPenalty: Int
        if send.attempts == "10+" {
            attemptsPenalty = 1 // 10+ always gives lowest penalty
        } else {
            if let attemptsInt = Int(send.attempts), attemptsInt >= 1 && attemptsInt <= 10 {
                // 1 → 10, 2 → 9, ..., 10 → 1
                attemptsPenalty = 11 - attemptsInt
            } else {
                // Fallback in case of bad data → give minimum score
                attemptsPenalty = 1
            }
        }
        
        // 4️⃣ Final Score Calculation
        let score = baseScore * statusMultiplier * attemptsPenalty
        return score
    }
    
    /// Calculates the leaderboard by aggregating scores per userId,
    /// sorting the users by total score in descending order,
    /// and updating the `rankingData` array for display.
    /// Finally, reloads the tableView to show updated results.
    func calculateLeaderboardAndRefresh() {
        
        // 1️⃣ Aggregate scores per userId
        var userScores: [String: Int] = [:] // [userId: totalScore]
        var userNames: [String: String] = [:] // [userId: userName]
        
        for send in allSends {
            // Calculate score for this send
            let score = calculateScore(for: send)
            
            // Skip sends with 0 score (e.g. Projecting)
            if score == 0 {
                continue
            }
            
            // Aggregate the score per userId
            userScores[send.userId, default: 0] += score
            userNames[send.userId] = send.userName
        }
        
        // 2️⃣ Sort users by total score in descending order
        let sortedUserScores = userScores.sorted { $0.value > $1.value }
        
        // 3️⃣ Build rankingData array
        rankingData.removeAll()
        
        var rank = 1
        for (userId, totalScore) in sortedUserScores {
            let userName = userNames[userId] ?? "Unknown"
            rankingData.append((rank: rank, name: userName, score: totalScore))
            rank += 1
        }
        
        print("🏆 Calculated leaderboard with \(rankingData.count) users.")
        
        // 4️⃣ Reload table view to display updated leaderboard
        tableView.reloadData()
    }

}
