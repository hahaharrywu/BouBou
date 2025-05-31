//
//  RankingViewController.swift
//  BouBou
//
//  Created by Hongrui Wu  on 5/25/25.
//

import UIKit

class RankingViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var tableView: UITableView!
    
    // for testing
    let rankingData = [
        (rank: 1, name: "User 1", score: 475, avatar: UIImage(named: "cat")),
        (rank: 2, name: "User 2", score: 450, avatar: UIImage(named: "dog"))
    ]

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = self
        tableView.delegate = self
    }
    

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rankingData.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RankingCell", for: indexPath) as! RankingTableViewCell
        let item = rankingData[indexPath.row]
        cell.rankLabel.text = "\(item.rank)"
        cell.nameLabel.text = item.name
        cell.scoreLabel.text = "\(item.score)"
        cell.avatarImageView.image = UIImage(systemName: "person.circle")
        return cell
    }

}
