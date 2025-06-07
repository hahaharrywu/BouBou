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
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ No current user.")
            return
        }

        let calendar = Calendar.current
        let today = Date()

        let db = Firestore.firestore()
        db.collection("sends")
            .whereField("userId", isEqualTo: currentUser.uid)
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching sends: \(error.localizedDescription)")
                    return
                }

                if let docs = snapshot?.documents {
                    let all = docs.compactMap { FeedSend(dict: $0.data()) }
                    let todaySends = all.filter { calendar.isDate($0.timestamp.dateValue(), inSameDayAs: today) }
                    print("📅 Found \(todaySends.count) sends from today.")
                    
                    DispatchQueue.main.async {
                        self.sends = todaySends
                        self.tableView.reloadData()
                    }
                }
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
