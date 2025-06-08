//
//  LastSessionViewController.swift
//  BouBou
//
//  Created by Hongrui Wu  on 6/6/25.
//

import UIKit
import Firebase
import FirebaseAuth

class LastSessionViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!

    var sends: [FeedSend] = []


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

                // Update UI on main thread
                DispatchQueue.main.async {
                    self.sends = sameDaySends
                    self.tableView.reloadData()
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

        cell.nameLabel.text = send.userName
        cell.sendInfoLabel.text = send.colorGrade
        cell.summaryLabel.text = "..."
        cell.feelingLabel.text = send.feeling
        cell.avatarImageView.image = UIImage(systemName: "person.circle")
        cell.summaryLabel.text = summaryPhrase(for: send.status, attempts: send.attempts)


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
}
