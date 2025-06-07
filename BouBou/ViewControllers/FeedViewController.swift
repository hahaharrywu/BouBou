//
//  FeedViewController.swift
//  BouBou
//
//  Created by Hongrui Wu  on 5/30/25.
//

import UIKit
import Firebase

// This struct represents one send record fetched from Firebase to display in the feed
struct FeedSend {
    let color: String
    let grade: String
    let status: String
    let attempts: String
    let feeling: String
    let imageUrl: String
    let userId: String
    let userName: String // New field: Will be email prefix for now
    let userEmail: String // New field: user email (optional, not displayed)
    let timestamp: Timestamp

    // Combines color and grade into Color-V# format for Send Info Label
    var colorGrade: String {
        return "\(color)-\(grade)"
    }
    
    // Initialize from Firebase document dictionary
    init(dict: [String: Any]) {
        self.color = dict["color"] as? String ?? "Color"
        self.grade = dict["grade"] as? String ?? "V?"
        self.status = dict["status"] as? String ?? ""
        self.attempts = dict["attempts"] as? String ?? "?"
        self.feeling = dict["feeling"] as? String ?? ""
        self.imageUrl = dict["imageUrl"] as? String ?? ""
        self.userId = dict["userId"] as? String ?? ""
        self.userName = dict["userName"] as? String ?? ""
        self.userEmail = dict["userEmail"] as? String ?? "unknown@example.com"
        self.timestamp = dict["timestamp"] as? Timestamp ?? Timestamp()
    }
}



class FeedViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var sends: [FeedSend] = []
    @IBOutlet weak var tableView: UITableView!
    
    //let testData = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]

    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("🌀 FeedViewController viewDidLoad called")
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.showsVerticalScrollIndicator = false
        
        // Add pull-to-refresh control
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
        // No need to call fetchData() here anymore
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        print("🌀 FeedViewController viewWillAppear called")
        
        fetchData()
    }
    
    // Load send records from Firestore and update the table view
    func fetchData() {
        let db = Firestore.firestore()
        db.collection("sends")
            .order(by: "timestamp", descending: true) // show latest sends first
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Failed to load sends: \(error.localizedDescription)")
                    return
                }

                // Map each document to a Send object
                self.sends = snapshot?.documents.compactMap {
                    let data = $0.data()
                    let send = FeedSend(dict: data)
                    print("📥 Fetched send with imageUrl: \(send.imageUrl)") // <<< 这里
                    return send
                } ?? []

                // Refresh the table view on the main thread
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
    }

    
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sends.count
    }

    // Configure the appearance of each feed row
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "FeedCell", for: indexPath) as? FeedTableViewCell else {
            return UITableViewCell()
        }

        let send = sends[indexPath.row] // Get the Send object for this row

        // Determine display name based on userName and fallback to email prefix if needed
        let displayName: String
        if send.userName.isEmpty {
            // If userName is empty, fallback to email prefix (before "@")
            displayName = send.userEmail.components(separatedBy: "@").first ?? "unknown"
        } else {
            // If userName is not empty, use it directly
            displayName = send.userName
        }

        // Set the name label to the display name
        cell.nameLabel.text = displayName


        // Set Send Info Label as "Color-V#" (example: "Red-V3")
        cell.sendInfoLabel.text = send.colorGrade


        // Set Summary Label as custom phrase based on status + attempts
        cell.summaryLabel.text = summaryPhrase(for: send.status, attempts: send.attempts)
        
        // Helper function to generate short summary phrase based on status and attempts
    
        func summaryPhrase(for status: String, attempts: String) -> String {
            switch status {
            case "Onsight":
                return "Onsight! Sent in 1 try."
            case "Flash":
                return "Flash! Sent in 1 try."
            case "Send":
                return "Sent in \(attempts) tries."
            case "Projecting":
                return "Projecting... \(attempts) tries so far."
            case "Fail":
                return "Didn't finish after \(attempts) tries."
            default:
                return ""
            }
        }



        // Show the user's comment/feeling
        cell.feelingLabel.text = send.feeling

        // Set a default avatar image
        cell.avatarImageView.image = UIImage(systemName: "person.circle")

        // Load the send image from URL (if any)
        if let url = URL(string: send.imageUrl), !send.imageUrl.isEmpty {
            print("🖼️ Loading image from URL: \(send.imageUrl)") // <<< check
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data {
                    DispatchQueue.main.async {
                        print("✅ Image data loaded successfully!") // <<< check
                        cell.sendImageView.image = UIImage(data: data)
                    }
                } else {
                    print("❌ Failed to load image data.")
                }
            }.resume()
        } else {
            print("🖼️ No image URL, showing default photo.") // <<< 这里
            cell.sendImageView.image = UIImage(systemName: "photo")
        }

        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
    }
    
    // Called when user pulls to refresh the Feed
    @objc func refreshPulled() {
        print("🔄 User triggered pull-to-refresh")
        fetchData()
        // End the refreshing animation
        tableView.refreshControl?.endRefreshing()
    }

}
