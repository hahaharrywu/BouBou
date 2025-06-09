//
//  FriendsViewController.swift
//  BouBou
//
//  Created by Hongrui Wu  on 6/9/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

struct Friend {
    let userId: String
    let customUserName: String
    let comment: String
    let avatarUrl: String
}


class FriendsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    
    var friends: [Friend] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchFriends()
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

        cell.nameLabel.text = nil
        cell.commentLabel.text = nil
        cell.avatarImageView.image = nil
        
        // option button
        cell.optionsButtonAction = { [weak self] in
            guard let self = self else { return }
            let friend = self.friends[indexPath.row]
            self.presentOptions(for: friend)
        }


        // name
        cell.nameLabel.text = friend.customUserName

        // comment
        cell.commentLabel.text = friend.comment

        // avatar
        cell.avatarImageView.image = UIImage(named: "Avatar_Cat")

        // head shot
        if let url = URL(string: friend.avatarUrl), !friend.avatarUrl.isEmpty {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        cell.avatarImageView.image = image
                    }
                }
            }.resume()
        }

        return cell
    }

    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    
    func fetchFriends() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        let followingRef = db.collection("users").document(currentUserId).collection("following")

        followingRef
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Failed to fetch following: \(error.localizedDescription)")
                    return
                }

                let followingDocs = snapshot?.documents ?? []

                var loadedFriends: [Friend] = []
                let group = DispatchGroup()

                for doc in followingDocs {
                    let userId = doc.documentID
                    let comment = doc.get("comment") as? String ?? "" // ✅ 从 follows 中读取 comment

                    group.enter()
                    db.collection("users").document(userId).getDocument { userDoc, error in
                        defer { group.leave() }

                        guard let userDoc = userDoc, userDoc.exists else {
                            print("⚠️ Missing user document for \(userId)")
                            return
                        }

                        let email = userDoc.get("email") as? String ?? "unknown@example.com"
                        let fallbackName = email.components(separatedBy: "@").first ?? "Unknown"
                        let customUserName = userDoc.get("customUserName") as? String ?? ""
                        let avatarUrl = userDoc.get("avatarUrl") as? String ?? ""

                        let displayName = customUserName.isEmpty ? fallbackName : customUserName

                        print("✅ Friend loaded: \(displayName)")

                        let friend = Friend(
                            userId: userId,
                            customUserName: displayName,
                            comment: comment, // ✅ 正确注入 comment
                            avatarUrl: avatarUrl
                        )
                        loadedFriends.append(friend)
                    }
                }

                group.notify(queue: .main) {
                    self.friends = loadedFriends
                    self.tableView.reloadData()
                }
            }
    }


    func presentOptions(for friend: Friend) {
        let alert = UIAlertController(title: "Options", message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Edit Comment", style: .default, handler: { _ in
            self.promptEditComment(for: friend)
        }))

        alert.addAction(UIAlertAction(title: "Remove Friend", style: .destructive, handler: { _ in
            self.confirmRemoveFriend(friend)
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        present(alert, animated: true)
    }


    func promptEditComment(for friend: Friend) {
        let alert = UIAlertController(title: "Edit Comment", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Enter a note"
            textField.text = friend.comment
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { _ in
            let newComment = alert.textFields?.first?.text ?? ""
            self.updateComment(for: friend, with: newComment)
        }))

        present(alert, animated: true)
    }

    func updateComment(for friend: Friend, with newComment: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        db.collection("users").document(currentUserId)
            .collection("following").document(friend.userId)
            .updateData(["comment": newComment]) { error in
                if let error = error {
                    print("❌ Failed to update comment: \(error.localizedDescription)")
                } else {
                    print("✅ Comment updated.")
                    self.fetchFriends()
                }
            }
    }

    
    func confirmRemoveFriend(_ friend: Friend) {
        let alert = UIAlertController(
            title: "Are you sure?",
            message: "This will remove \(friend.customUserName) from your friends.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Remove", style: .destructive, handler: { _ in
            self.removeFriend(friend)
        }))

        present(alert, animated: true)
    }

    func removeFriend(_ friend: Friend) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        db.collection("users").document(currentUserId)
            .collection("following").document(friend.userId)
            .delete { error in
                if let error = error {
                    print("❌ Failed to remove friend: \(error.localizedDescription)")
                } else {
                    print("✅ Friend removed.")
                    self.fetchFriends()
                }
            }
    }


}
