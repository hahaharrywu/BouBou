//
//  FriendsViewController.swift
//  BouBou
//
//  Created by Hongrui Wu  on 6/9/25.
//

import UIKit

class FriendsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    
    var friends: [Friend] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    @IBAction func didTapRequestsButton(_ sender: UIBarButtonItem) {
        performSegue(withIdentifier: "goToFriendRequests", sender: self)
    }
    

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friends.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let friend = friends[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "FriendCell", for: indexPath) as? FriendTableViewCell else {
            return UITableViewCell()
        }

        cell.nameLabel.text = friend.userName
        cell.commentLabel.text = friend.comment
        cell.avatarImageView.image = UIImage(named: "Avatar_Cat")

        return cell
    }

}





struct Friend {
    let userName: String
    let comment: String
    let avatarUrl: String
}
