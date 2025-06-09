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

    // MARK: - Properties

    var allSends: [SendRecord] = []
    let refreshControl = UIRefreshControl()

    enum RankingMode {
        case world
        case friends
    }

    var selectedMode: RankingMode = .world
    var avatarUrlCache = [String: String]()   // userId -> avatarUrl
    var userNameCache = [String: String]()    // userId -> customUserName
    var rankingData: [(rank: Int, userId: String, name: String, score: Int)] = []

    // MARK: - Outlets

    @IBOutlet weak var tableView: UITableView!

    // MARK: - Actions

    @IBAction func rankingSegmentChanged(_ sender: UISegmentedControl) {
        selectedMode = (sender.selectedSegmentIndex == 0) ? .world : .friends
        fetchSharedSends()
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = self
        tableView.delegate = self

        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl

        fetchSharedSends()
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rankingData.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RankingCell", for: indexPath) as! RankingTableViewCell
        let item = rankingData[indexPath.row]
        configureCell(cell, with: item)
        return cell
    }

    // MARK: - UI Update Methods

    @objc func handleRefresh() {
        print("🔄 Pull to refresh triggered.")
        fetchSharedSends()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refreshControl.endRefreshing()
        }
    }

    func loadImage(with url: URL, into imageView: UIImageView) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    imageView.image = image
                }
            }
        }.resume()
    }

    func configureCell(_ cell: RankingTableViewCell, with item: (rank: Int, userId: String, name: String, score: Int)) {
        cell.rankLabel.text = "\(item.rank)"
        cell.scoreLabel.text = "\(item.score) pts"

        if let cachedName = userNameCache[item.userId] {
            cell.nameLabel.text = cachedName
        } else {
            cell.nameLabel.text = item.name
        }

        if let cachedUrl = avatarUrlCache[item.userId], let url = URL(string: cachedUrl) {
            loadImage(with: url, into: cell.avatarImageView)
        } else {
            cell.avatarImageView.image = UIImage(named: "Avatar_Cat")
            let db = Firestore.firestore()
            db.collection("users").document(item.userId).getDocument { snapshot, _ in
                guard let doc = snapshot, doc.exists else {
                    print("⚠️ No user document for \(item.userId)")
                    return
                }

                let avatarUrl = doc.get("avatarUrl") as? String ?? ""
                let customName = doc.get("customUserName") as? String ?? ""

                DispatchQueue.main.async {
                    if !avatarUrl.isEmpty, let url = URL(string: avatarUrl) {
                        self.avatarUrlCache[item.userId] = avatarUrl
                        self.loadImage(with: url, into: cell.avatarImageView)
                    }
                    if !customName.isEmpty {
                        self.userNameCache[item.userId] = customName
                        cell.nameLabel.text = customName
                    }
                }
            }
        }
    }

    // MARK: - Firestore Data Fetching

    func fetchSharedSends() {
        let db = Firestore.firestore()
        let sendsRef = db.collection("sends").whereField("isShared", isEqualTo: true)

        if selectedMode == .friends {
            guard let currentUserId = Auth.auth().currentUser?.uid else { return }

            db.collection("users").document(currentUserId).collection("following")
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("❌ Failed to fetch following: \(error)")
                        return
                    }

                    let followedUserIds = snapshot?.documents.map { $0.documentID } ?? []
                    if followedUserIds.isEmpty {
                        self.allSends = []
                        self.rankingData = []
                        self.tableView.reloadData()
                        return
                    }

                    sendsRef.whereField("userId", in: followedUserIds)
                        .getDocuments { snapshot, error in
                            self.processSendSnapshot(snapshot, error)
                        }
                }
        } else {
            sendsRef.getDocuments { snapshot, error in
                self.processSendSnapshot(snapshot, error)
            }
        }
    }

    private func processSendSnapshot(_ snapshot: QuerySnapshot?, _ error: Error?) {
        if let error = error {
            print("❌ Failed to fetch sends: \(error)")
            return
        }

        self.allSends.removeAll()
        for document in snapshot?.documents ?? [] {
            let data = document.data()
            let sendRecord = SendRecord(documentID: document.documentID, dict: data)
            self.allSends.append(sendRecord)
        }

        print("✅ Loaded \(allSends.count) sends.")
        self.calculateLeaderboardAndRefresh()
    }

    // MARK: - Leaderboard Logic

    func calculateScore(for send: SendRecord) -> Int {
        let gradeNumber = Int(send.grade.replacingOccurrences(of: "V", with: "")) ?? 0
        let baseScore = gradeNumber * 10

        let statusMultiplier: Int
        switch send.status {
        case "Onsight": statusMultiplier = 5
        case "Flash": statusMultiplier = 4
        case "Send": statusMultiplier = 3
        default: statusMultiplier = 0
        }

        let attemptsPenalty: Int
        if send.attempts == "10+" {
            attemptsPenalty = 1
        } else if let attemptsInt = Int(send.attempts), attemptsInt >= 1 && attemptsInt <= 10 {
            attemptsPenalty = 11 - attemptsInt
        } else {
            attemptsPenalty = 1
        }

        return baseScore * statusMultiplier * attemptsPenalty
    }

    func calculateLeaderboardAndRefresh() {
        var userScores: [String: Int] = [:]
        var userNames: [String: String] = [:]

        for send in allSends {
            let score = calculateScore(for: send)
            if score == 0 { continue }
            userScores[send.userId, default: 0] += score
            userNames[send.userId] = send.userName
        }

        let sortedUserScores = userScores.sorted { $0.value > $1.value }

        rankingData.removeAll()
        var rank = 1
        for (userId, totalScore) in sortedUserScores {
            let userName = userNames[userId] ?? "Unknown"
            rankingData.append((rank: rank, userId: userId, name: userName, score: totalScore))
            rank += 1
        }

        print("🏆 Calculated leaderboard with \(rankingData.count) users.")
        tableView.reloadData()
    }
}
