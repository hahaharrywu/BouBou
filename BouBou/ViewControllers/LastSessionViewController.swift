//
//  LastSessionViewController.swift
//  BouBou
//
//  Created by Hongrui Wu  on 6/6/25.
//

import UIKit
import Firebase
import FirebaseAuth
import SDWebImage

class LastSessionViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var dateLabel: UILabel!
    
    

    var sends: [FeedSend] = []
    var userNameCache: [String: String] = [:]
    var avatarUrlCache: [String: String] = [:]


    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        tableView.delegate = self
        tableView.dataSource = self

        
        fetchData()
    }

    
    func fetchData() {
        // Ensure the user is logged in
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ No current user.")
            return
        }

        let db = Firestore.firestore()
        let calendar = Calendar.current

        // Query sends for this user, ordered by newest first
        db.collection("sends")
            .whereField("userId", isEqualTo: currentUser.uid)
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching sends: \(error.localizedDescription)")
                    return
                }

                // Convert Firestore documents to FeedSend models
                guard let docs = snapshot?.documents else { return }
                let allSends = docs.compactMap {
                    FeedSend(documentID: $0.documentID, dict: $0.data())
                }

                // Find the date of the most recent send
                guard let latestDate = allSends.first?.timestamp.dateValue() else {
                    print("📭 No sends found.")
                    return
                }

                // Filter all sends from the same day as the latest send
                let sameDaySends = allSends.filter {
                    calendar.isDate($0.timestamp.dateValue(), inSameDayAs: latestDate)
                }

                print("📅 Found \(sameDaySends.count) sends from the most recent session.")

                // Update UI on main thread and date
                DispatchQueue.main.async {
                    self.sends = sameDaySends
                    self.tableView.reloadData()

                    // Format the date and set it on the label
                    let formatter = DateFormatter()
                    formatter.dateStyle = .long // Example: June 8, 2025
                    formatter.timeStyle = .none
//                    formatter.dateFormat = "MM-dd-yyyy"
                    self.dateLabel.text = "on \(formatter.string(from: latestDate))"
                }

            }
    }

    
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




}


extension LastSessionViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sends.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "FeedCell", for: indexPath) as? FeedTableViewCell else {
            return UITableViewCell()
        }

        let send = sends[indexPath.row]


        cell.sendInfoLabel.text = send.colorGrade
        cell.summaryLabel.text = "..."
        cell.feelingLabel.text = send.feeling
        cell.summaryLabel.text = summaryPhrase(for: send.status, attempts: send.attempts)
        
        if let cachedName = userNameCache[send.userId] {
            cell.nameLabel.text = cachedName
        } else {
            let db = Firestore.firestore()
            db.collection("users").document(send.userId).getDocument { snapshot, error in
                if let doc = snapshot, doc.exists {
                    let customName = doc.get("customUserName") as? String ?? ""
                    let email = doc.get("email") as? String ?? "unknown@example.com"
                    let fallbackName = email.components(separatedBy: "@").first ?? "Unknown"
                    let finalName = customName.isEmpty ? fallbackName : customName

                    self.userNameCache[send.userId] = finalName

                    DispatchQueue.main.async {
                        if let visibleCell = tableView.cellForRow(at: indexPath) as? FeedTableViewCell {
                            visibleCell.nameLabel.text = finalName
                        }
                    }
                }
            }
        }

        if let cachedUrl = avatarUrlCache[send.userId], let url = URL(string: cachedUrl) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data {
                    DispatchQueue.main.async {
                        cell.avatarImageView.image = UIImage(data: data)
                    }
                }
            }.resume()
        } else {
            let db = Firestore.firestore()
            db.collection("users").document(send.userId).getDocument { snapshot, error in
                if let doc = snapshot, doc.exists,
                   let avatarUrl = doc.get("avatarUrl") as? String,
                   !avatarUrl.isEmpty,
                   let url = URL(string: avatarUrl) {
                    self.avatarUrlCache[send.userId] = avatarUrl
                    DispatchQueue.main.async {
                        if let visibleCell = tableView.cellForRow(at: indexPath) as? FeedTableViewCell {
                            visibleCell.avatarImageView.sd_setImage(with: url, placeholderImage: UIImage(named: "Avatar_Cat"))
                        }
                    }

                } else {
                    DispatchQueue.main.async {
                        cell.avatarImageView.image = UIImage(named: "Avatar_Cat") // fallback image
                    }
                }
            }
        }


        if let url = URL(string: send.imageUrl), !send.imageUrl.isEmpty {
            cell.sendImageView.sd_setImage(with: url, placeholderImage: UIImage(systemName: "photo"))
        } else {
            cell.sendImageView.image = UIImage(systemName: "photo")
        }

        return cell
    }
}
