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
        self.timestamp = dict["timestamp"] as? Timestamp ?? Timestamp()
    }
}



class FeedViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var sends: [FeedSend] = []
    @IBOutlet weak var tableView: UITableView!
    
    //let testData = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
        tableView.showsVerticalScrollIndicator = false
        
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
                    FeedSend(dict: $0.data())
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

        // Set the name as "username"
        cell.nameLabel.text = "Anon"


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
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data {
                    DispatchQueue.main.async {
                        cell.sendImageView.image = UIImage(data: data)
                    }
                }
            }.resume()
        } else {
            cell.sendImageView.image = UIImage(systemName: "photo")
        }

        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
    }

}
