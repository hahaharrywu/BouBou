//
//  ChatViewController.swift
//  BouBou
//
//  Created by Hongrui Wu  on 5/30/25.
//

import UIKit
import Firebase
import FirebaseFirestore

class ChatViewController: UIViewController {
    
    @IBOutlet weak var chatsTableView: UITableView!
    @IBOutlet weak var addFriendButton: UIBarButtonItem!
    @IBOutlet weak var requestsButton: UIBarButtonItem!

    private var chats: [Chat] = []
    private let db = Firestore.firestore()
    private var currentUser: User?
    private var chatsListener: ListenerRegistration?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        getCurrentUser()
        setupTableView()
        loadChats()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateRequestsButtonBadge()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        chatsListener?.remove()
    }
    
    private func setupUI() {
        navigationController?.navigationBar.prefersLargeTitles = true
    }
    
    private func setupTableView() {
        // todo - table styling
    }
    
    private func getCurrentUser() {
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            print("No current user found")
            return
        }
        
        db.collection("users").document(currentUserID).getDocument { [weak self] document, error in
            if let error = error {
                print("Error fetching current user: \(error)")
                return
            }
            
            guard let document = document, document.exists,
                  let data = document.data() else {
                print("Current user document doesn't exist")
                return
            }
            
            self?.currentUser = User(
                id: currentUserID,
                email: data["email"] as? String ?? "",
                username: data["username"] as? String ?? "",
                profileImageURL: data["profileImageURL"] as? String
            )
        }
    }
    
    private func loadChats() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        chatsListener = db.collection("chats")
            .whereField("participants", arrayContains: currentUserID)
            .order(by: "lastMessageTimestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching chats: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self?.chats = documents.compactMap { document in
                    let data = document.data()
                    return Chat(
                        id: document.documentID,
                        participants: data["participants"] as? [String] ?? [],
                        lastMessage: data["lastMessage"] as? String ?? "",
                        lastMessageTimestamp: data["lastMessageTimestamp"] as? Timestamp ?? Timestamp(),
                        participantNames: data["participantNames"] as? [String: String] ?? [:]
                    )
                }
                
                DispatchQueue.main.async {
                    self?.chatsTableView.reloadData()
                }
            }
    }
    
    private func sendFriendRequest(to userID: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid,
              let currentUser = self.currentUser else { return }
        
        // check if request already exists
        db.collection("friendRequests")
            .whereField("senderID", isEqualTo: currentUserID)
            .whereField("recipientID", isEqualTo: userID)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error checking existing requests: \(error)")
                    return
                }
                
                if let existingRequest = snapshot?.documents.first {
                    let status = existingRequest.data()["status"] as? String ?? ""
                    if status == "pending" {
                        self?.showAlert(message: "Friend request already sent")
                        return
                    }
                }
                
                // otherwise create new friend request
                let requestData: [String: Any] = [
                    "senderID": currentUserID,
                    "recipientID": userID,
                    "senderUsername": currentUser.username,
                    "status": "pending",
                    "timestamp": Timestamp()
                ]
                
                self?.db.collection("friendRequests").addDocument(data: requestData) { error in
                    if let error = error {
                        print("Error sending friend request: \(error)")
                        self?.showAlert(message: "Failed to send friend request")
                    } else {
                        self?.showAlert(message: "Friend request sent!")
                    }
                }
            }
    }
    
    private func createChatBetweenFriends(userID1: String, userID2: String) {
        let group = DispatchGroup()
        var user1: User?
        var user2: User?
        
        group.enter()
        getUserInfo(userID: userID1) { user in
            user1 = user
            group.leave()
        }
        
        group.enter()
        getUserInfo(userID: userID2) { user in
            user2 = user
            group.leave()
        }
        
        group.notify(queue: .main) {
            guard let user1 = user1, let user2 = user2 else {
                print("Failed to get user info for chat creation")
                return
            }
            
            let chatData: [String: Any] = [
                "participants": [user1.id, user2.id],
                "participantNames": [
                    user1.id: user1.username,
                    user2.id: user2.username
                ],
                "lastMessageTimestamp": Timestamp(),
                "createdAt": Timestamp()
            ]
            
            self.db.collection("chats").addDocument(data: chatData) { error in
                if let error = error {
                    print("Error creating chat: \(error)")
                } else {
                    print("Chat created successfully between \(user1.username) and \(user2.username)")
                }
            }
        }
    }
    
    private func getUserInfo(userID: String, completion: @escaping (User?) -> Void) {
        db.collection("users").document(userID).getDocument { document, error in
            if let error = error {
                print("Error fetching user info: \(error)")
                completion(nil)
                return
            }
            
            guard let document = document, document.exists,
                  let data = document.data() else {
                completion(nil)
                return
            }
            
            let user = User(
                id: userID,
                email: data["email"] as? String ?? "",
                username: data["username"] as? String ?? "",
                profileImageURL: data["profileImageURL"] as? String
            )
            completion(user)
        }
    }
    
    @IBAction func addFriendButtonTapped(_ sender: UIBarButtonItem) {
        showAddFriendAlert()
    }
    
    @IBAction func requestsButtonTapped(_ sender: UIBarButtonItem) {
        showFriendRequestsViewController()
    }
    
    private func showAddFriendAlert() {
        let alert = UIAlertController(title: "Add Friend", message: "Enter User ID or search by username", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "User ID or Username"
            textField.autocapitalizationType = .none
        }
        
        let searchAction = UIAlertAction(title: "Search", style: .default) { [weak self] _ in
            guard let searchText = alert.textFields?.first?.text,
                  !searchText.isEmpty else { return }
            
            if searchText.count == 28 && searchText.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil {
                self?.searchUserByID(searchText)
            } else {
                self?.searchUserByUsername(searchText)
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(searchAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    private func searchUserByID(_ userID: String) {
        db.collection("users").document(userID).getDocument { [weak self] document, error in
            if let error = error {
                print("Error searching user: \(error)")
                self?.showAlert(message: "Error searching for user")
                return
            }
            
            guard let document = document, document.exists else {
                self?.showAlert(message: "User not found")
                return
            }
            
            let data = document.data() ?? [:]
            let user = User(
                id: document.documentID,
                email: data["email"] as? String ?? "",
                username: data["username"] as? String ?? "",
                profileImageURL: data["profileImageURL"] as? String
            )
            
            DispatchQueue.main.async {
                // todo
            }
        }
    }
    
    private func searchUserByUsername(_ username: String) {
        db.collection("users")
            .whereField("username", isEqualTo: username.lowercased())
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error searching user: \(error)")
                    self?.showAlert(message: "Error searching for user")
                    return
                }
                
                guard let documents = snapshot?.documents,
                      let document = documents.first else {
                    self?.showAlert(message: "User not found")
                    return
                }
                
                let data = document.data()
                let user = User(
                    id: document.documentID,
                    email: data["email"] as? String ?? "",
                    username: data["username"] as? String ?? "",
                    profileImageURL: data["profileImageURL"] as? String
                )
                
                DispatchQueue.main.async {
                    // todo
                }
            }
    }
    
    private func showFriendRequestsViewController() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let requestsVC = storyboard.instantiateViewController(withIdentifier: "FriendRequestsViewController") as? FriendRequestsViewController {
            let navController = UINavigationController(rootViewController: requestsVC)
            present(navController, animated: true)
        }
    }
    
    private func updateRequestsButtonBadge() {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        db.collection("friendRequests")
            .whereField("recipientID", isEqualTo: currentUserID)
            .whereField("status", isEqualTo: "pending")
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching request count: \(error)")
                    return
                }
                
                let count = snapshot?.documents.count ?? 0
                DispatchQueue.main.async {
                    if count > 0 {
                        self?.requestsButton.title = "Requests (\(count))"
                        self?.requestsButton.tintColor = .systemRed
                    } else {
                        self?.requestsButton.title = "Requests"
                        self?.requestsButton.tintColor = .systemBlue
                    }
                }
            }
    }
    
    private func navigateToMessages(chatID: String) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let messagesVC = storyboard.instantiateViewController(withIdentifier: "MessagesViewController") as? MessagesViewController {
            messagesVC.chatID = chatID
            navigationController?.pushViewController(messagesVC, animated: true)
        }
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Notice", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

struct Chat {
    let id: String
    let participants: [String]
    let lastMessageTimestamp: Timestamp
    let participantNames: [String: String]
}

struct User {
    let id: String
    let email: String
    let username: String
    let profileImageURL: String?
}

struct FriendRequest {
    let id: String
    let senderID: String
    let recipientID: String
    let senderUsername: String
    let status: String // "pending", "accepted", "declined"
    let timestamp: Timestamp
}
