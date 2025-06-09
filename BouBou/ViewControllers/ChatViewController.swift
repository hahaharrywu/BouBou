//
//  ChatViewController.swift
//  BouBou
//
//  Created by Hongrui Wu  on 5/30/25.
//

import UIKit
import Firebase
import FirebaseFirestore
import FirebaseAuth //Cecilia added

class ChatViewController: UIViewController {
    
    @IBOutlet weak var chatsTableView: UITableView!
//    @IBOutlet weak var addFriendButton: UIBarButtonItem!
//    @IBOutlet weak var requestsButton: UIBarButtonItem!

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
    
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//        updateRequestsButtonBadge()
//    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        chatsListener?.remove()
    }
    
    private func setupUI() {
        title = "Chats"
        navigationController?.navigationBar.prefersLargeTitles = true
    }
    
    @IBAction func didTapRequestsButton(_ sender: UIBarButtonItem) {
        performSegue(withIdentifier: "goToFriendRequests", sender: self)
    }

    
    private func setupTableView() {
        chatsTableView.delegate = self
        chatsTableView.dataSource = self
        chatsTableView.register(ChatTableViewCell.self, forCellReuseIdentifier: "ChatCell")
        chatsTableView.separatorStyle = .singleLine
        chatsTableView.rowHeight = 80
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
                "lastMessage": "",
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
    
    
    /*delete search UserByID and searchUserByUsername and uncomment this function if we want only searchbyEmail (BEEM)
     
    private func searchUserByEmail(_ email: String) {
        db.collection("users")
            .whereField("email", isEqualTo: email.lowercased())
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error searching user: \(error)")
                    self?.showAlert(message: "Error searching for user")
                    return
                }

                guard let document = snapshot?.documents.first else {
                    self?.showAlert(message: "User not found")
                    return
                }

                let data = document.data()
                let user = User(
                    id: document.documentID,
                    email: data["email"] as? String ?? "",
                    username: data["customUserName"] as? String ?? data["username"] as? String ?? "",
                    profileImageURL: data["avatarUrl"] as? String ?? data["profileImageURL"] as? String
                )

                self?.handleUserFound(user)
            }
    }*/
    
    
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
                self?.showUserActionSheet(for: user)
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
                    self?.showUserActionSheet(for: user)
                }
            }
    }
    
    private func showUserActionSheet(for user: User) {
        guard let currentUserID = Auth.auth().currentUser?.uid,
              user.id != currentUserID else {
            showAlert(message: "You cannot add yourself as a friend")
            return
        }
        
        let actionSheet = UIAlertController(title: user.username, message: "User ID: \(user.id)", preferredStyle: .actionSheet)
        let sendRequestAction = UIAlertAction(title: "Send Friend Request", style: .default) { [weak self] _ in
            //self?.sendFriendRequest(to: user.id)  - can delete the chunk below and uncomment this (BEEM)
            self?.db.collection("chats")
                    .whereField("participants", arrayContains: currentUserID)
                    .getDocuments { [weak self] snapshot, error in
                        if let error = error {
                            print("Error checking existing chats: \(error)")
                            self?.showAlert(message: "Failed to check existing chats.")
                            return
                        }

                        let chatExists = snapshot?.documents.contains(where: { doc in
                            let participants = doc.data()["participants"] as? [String] ?? []
                            return participants.contains(user.id)
                        }) ?? false

                        if chatExists {
                            self?.showAlert(message: "\(user.username) is already in your chat list.")
                        } else {
                            self?.createChatBetweenFriends(userID1: currentUserID, userID2: user.id)
                            self?.showAlert(message: "\(user.username) has been added to your chat.")
                        }
                    }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        actionSheet.addAction(sendRequestAction)
        actionSheet.addAction(cancelAction)
        
        present(actionSheet, animated: true)
    }
    
    private func showFriendRequestsViewController() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let requestsVC = storyboard.instantiateViewController(withIdentifier: "FriendRequestsViewController") as? FriendRequestsViewController {
            let navController = UINavigationController(rootViewController: requestsVC)
            present(navController, animated: true)
        }
    }
    
//    private func updateRequestsButtonBadge() {
//        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
//        
//        db.collection("friendRequests")
//            .whereField("recipientID", isEqualTo: currentUserID)
//            .whereField("status", isEqualTo: "pending")
//            .getDocuments { [weak self] snapshot, error in
//                if let error = error {
//                    print("Error fetching request count: \(error)")
//                    return
//                }
//                
//                let count = snapshot?.documents.count ?? 0
//                DispatchQueue.main.async {
//                    if count > 0 {
//                        self?.requestsButton.title = "Requests (\(count))"
//                        self?.requestsButton.tintColor = .systemRed
//                    } else {
//                        self?.requestsButton.title = "Requests"
//                        self?.requestsButton.tintColor = .systemBlue
//                    }
//                }
//            }
//    }
    
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
    
    private func getChatDisplayName(for chat: Chat) -> String {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return "Unknown" }
        
        let otherParticipants = chat.participants.filter { $0 != currentUserID }
        if let otherParticipantID = otherParticipants.first,
           let name = chat.participantNames[otherParticipantID] {
            return name
        }
        
        return "Chat"
    }
}

extension ChatViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chats.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChatCell", for: indexPath) as! ChatTableViewCell
        let chat = chats[indexPath.row]
        
        cell.configure(with: chat, displayName: getChatDisplayName(for: chat))
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let chat = chats[indexPath.row]
        navigateToMessages(chatID: chat.id)
    }
}

struct Chat {
    let id: String
    let participants: [String]
    let lastMessage: String
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

class ChatTableViewCell: UITableViewCell {
    
    private let profileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 25
        imageView.backgroundColor = .systemGray5
        return imageView
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private let lastMessageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        return label
    }()
    
    private let timeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.addSubview(profileImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(lastMessageLabel)
        contentView.addSubview(timeLabel)
        
        NSLayoutConstraint.activate([
            profileImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            profileImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 50),
            profileImageView.heightAnchor.constraint(equalToConstant: 50),
            
            nameLabel.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -8),
            
            lastMessageLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            lastMessageLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            lastMessageLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            lastMessageLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),//(BEEM)
            
            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            timeLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor)
        ])
    }
    
    func configure(with chat: Chat, displayName: String) {
        nameLabel.text = displayName
        lastMessageLabel.text = chat.lastMessage.isEmpty ? "No messages yet" : chat.lastMessage
        
        let formatter = DateFormatter()
        let date = chat.lastMessageTimestamp.dateValue()
        
        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
        } else if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "E"
        } else {
            formatter.dateFormat = "M/d/yy"
        }
        
        timeLabel.text = formatter.string(from: date)
        
        profileImageView.image = UIImage(systemName: "person.circle.fill")
        profileImageView.tintColor = .systemBlue
    }
}
