//
//  FriendRequestsViewController.swift
//  BouBou
//
//  Created by An Nguyen on 6/3/25.
//

import UIKit
import Firebase
import FirebaseFirestore
import FirebaseAuth

class FriendRequestsViewController: UIViewController {
    
    @IBOutlet weak var requestsTableView: UITableView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    private var incomingRequests: [FriendRequest] = []
    private var outgoingRequests: [FriendRequest] = []
    private let db = Firestore.firestore()
    private var currentUserID: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        getCurrentUserID()
        loadRequests()
    }
    
    private func setupUI() {
        title = "Friend Requests"
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeButtonTapped)
        )
        
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
    }
    
    private func setupTableView() {
        requestsTableView.delegate = self
        requestsTableView.dataSource = self
        requestsTableView.register(FriendRequestTableViewCell.self, forCellReuseIdentifier: "RequestCell")
        requestsTableView.separatorStyle = .singleLine
        requestsTableView.rowHeight = UITableView.automaticDimension
        requestsTableView.estimatedRowHeight = 80
    }
    
    private func getCurrentUserID() {
        currentUserID = Auth.auth().currentUser?.uid
    }
    
    private func loadRequests() {
        guard let currentUserID = currentUserID else { return }
        
        loadIncomingRequests(for: currentUserID)
        loadOutgoingRequests(for: currentUserID)
    }
    
    private func loadIncomingRequests(for userID: String) {
        db.collection("friendRequests")
            .whereField("recipientID", isEqualTo: userID)
            .whereField("status", isEqualTo: "pending")
            .order(by: "timestamp", descending: true)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching incoming requests: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self?.incomingRequests = documents.compactMap { document in
                    let data = document.data()
                    return FriendRequest(
                        id: document.documentID,
                        senderID: data["senderID"] as? String ?? "",
                        recipientID: data["recipientID"] as? String ?? "",
                        senderUsername: data["senderUsername"] as? String ?? "",
                        status: data["status"] as? String ?? "",
                        timestamp: data["timestamp"] as? Timestamp ?? Timestamp()
                    )
                }
                
                DispatchQueue.main.async {
                    if self?.segmentedControl.selectedSegmentIndex == 0 {
                        self?.requestsTableView.reloadData()
                    }
                }
            }
    }
    
    private func loadOutgoingRequests(for userID: String) {
        db.collection("friendRequests")
            .whereField("senderID", isEqualTo: userID)
            .order(by: "timestamp", descending: true)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching outgoing requests: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self?.outgoingRequests = documents.compactMap { document in
                    let data = document.data()
                    return FriendRequest(
                        id: document.documentID,
                        senderID: data["senderID"] as? String ?? "",
                        recipientID: data["recipientID"] as? String ?? "",
                        senderUsername: data["senderUsername"] as? String ?? "",
                        status: data["status"] as? String ?? "",
                        timestamp: data["timestamp"] as? Timestamp ?? Timestamp()
                    )
                }
                
                DispatchQueue.main.async {
                    if self?.segmentedControl.selectedSegmentIndex == 1 {
                        self?.requestsTableView.reloadData()
                    }
                }
            }
    }
    
    private func acceptFriendRequest(_ request: FriendRequest) {
        db.collection("friendRequests").document(request.id).updateData([
            "status": "accepted"
        ]) { [weak self] error in
            if let error = error {
                print("Error accepting request: \(error)")
                self?.showAlert(message: "Failed to accept friend request")
                return
            }
            
            self?.addFriendship(userID1: request.senderID, userID2: request.recipientID)
        }
    }
    
    private func declineFriendRequest(_ request: FriendRequest) {
        db.collection("friendRequests").document(request.id).updateData([
            "status": "declined"
        ]) { [weak self] error in
            if let error = error {
                print("Error declining request: \(error)")
                self?.showAlert(message: "Failed to decline friend request")
            } else {
                self?.loadRequests()
            }
        }
    }
    
    private func cancelFriendRequest(_ request: FriendRequest) {
        db.collection("friendRequests").document(request.id).delete { [weak self] error in
            if let error = error {
                print("Error canceling request: \(error)")
                self?.showAlert(message: "Failed to cancel friend request")
            } else {
                self?.loadRequests()
            }
        }
    }
    
    private func addFriendship(userID1: String, userID2: String) {
        let batch = db.batch()
        
        let friendship1Ref = db.collection("users").document(userID1).collection("friends").document(userID2)
        batch.setData(["friendID": userID2, "timestamp": Timestamp()], forDocument: friendship1Ref)
        
        let friendship2Ref = db.collection("users").document(userID2).collection("friends").document(userID1)
        batch.setData(["friendID": userID1, "timestamp": Timestamp()], forDocument: friendship2Ref)
        
        batch.commit { [weak self] error in
            if let error = error {
                print("Error creating friendship: \(error)")
                self?.showAlert(message: "Failed to create friendship")
            } else {
                self?.createChatBetweenFriends(userID1: userID1, userID2: userID2)
                self?.showAlert(message: "Friend request accepted! Chat created.")
                self?.loadRequests()
            }
        }
    }
    
    private func createChatBetweenFriends(userID1: String, userID2: String) {
        db.collection("chats")
            .whereField("participants", arrayContains: userID1)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error checking existing chats: \(error)")
                    return
                }
                
                let existingChat = snapshot?.documents.first { document in
                    let participants = document.data()["participants"] as? [String] ?? []
                    return participants.contains(userID2) && participants.count == 2
                }
                
                if existingChat != nil {
                    print("Chat already exists between users")
                    return
                }
                
                let group = DispatchGroup()
                var user1: [String: Any]?
                var user2: [String: Any]?
                
                group.enter()
                self?.db.collection("users").document(userID1).getDocument { document, error in
                    if let document = document, document.exists {
                        user1 = document.data()
                    }
                    group.leave()
                }
                
                group.enter()
                self?.db.collection("users").document(userID2).getDocument { document, error in
                    if let document = document, document.exists {
                        user2 = document.data()
                    }
                    group.leave()
                }
                
                group.notify(queue: .main) {
                    guard let user1Data = user1, let user2Data = user2,
                          let user1Name = user1Data["username"] as? String,
                          let user2Name = user2Data["username"] as? String else {
                        print("Failed to get user info for chat creation")
                        return
                    }
                    
                    let chatData: [String: Any] = [
                        "participants": [userID1, userID2],
                        "participantNames": [
                            userID1: user1Name,
                            userID2: user2Name
                        ],
                        "lastMessage": "",
                        "lastMessageTimestamp": Timestamp(),
                        "createdAt": Timestamp()
                    ]
                    
                    self?.db.collection("chats").addDocument(data: chatData) { error in
                        if let error = error {
                            print("Error creating chat: \(error)")
                        } else {
                            print("Chat created successfully between \(user1Name) and \(user2Name)")
                        }
                    }
                }
            }
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func segmentChanged() {
        requestsTableView.reloadData()
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Notice", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func getCurrentRequests() -> [FriendRequest] {
        return segmentedControl.selectedSegmentIndex == 0 ? incomingRequests : outgoingRequests
    }
    
    private func showActionSheet(for request: FriendRequest, at indexPath: IndexPath) {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        if segmentedControl.selectedSegmentIndex == 0 {
            let acceptAction = UIAlertAction(title: "Accept", style: .default) { [weak self] _ in
                self?.acceptFriendRequest(request)
            }
            acceptAction.setValue(UIColor.systemGreen, forKey: "titleTextColor")
            
            let declineAction = UIAlertAction(title: "Decline", style: .destructive) { [weak self] _ in
                self?.declineFriendRequest(request)
            }
            
            actionSheet.addAction(acceptAction)
            actionSheet.addAction(declineAction)
        } else {
            if request.status == "pending" {
                let cancelAction = UIAlertAction(title: "Cancel Request", style: .destructive) { [weak self] _ in
                    self?.cancelFriendRequest(request)
                }
                actionSheet.addAction(cancelAction)
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        actionSheet.addAction(cancelAction)
        
        present(actionSheet, animated: true)
    }
}

extension FriendRequestsViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return getCurrentRequests().count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RequestCell", for: indexPath) as! FriendRequestTableViewCell
        let request = getCurrentRequests()[indexPath.row]
        let isIncoming = segmentedControl.selectedSegmentIndex == 0
        
        cell.configure(with: request, isIncoming: isIncoming)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let request = getCurrentRequests()[indexPath.row]
        showActionSheet(for: request, at: indexPath)
    }
}

class FriendRequestTableViewCell: UITableViewCell {
    
    private let profileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 25
        imageView.backgroundColor = .systemGray5
        return imageView
    }()
    
    private let usernameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
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
        contentView.addSubview(usernameLabel)
        contentView.addSubview(statusLabel)
        contentView.addSubview(timeLabel)
        
        NSLayoutConstraint.activate([
            profileImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            profileImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 50),
            profileImageView.heightAnchor.constraint(equalToConstant: 50),
            
            usernameLabel.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 12),
            usernameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            usernameLabel.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -8),
            
            statusLabel.leadingAnchor.constraint(equalTo: usernameLabel.leadingAnchor),
            statusLabel.topAnchor.constraint(equalTo: usernameLabel.bottomAnchor, constant: 4),
            statusLabel.trailingAnchor.constraint(equalTo: usernameLabel.trailingAnchor),
            statusLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            timeLabel.centerYAnchor.constraint(equalTo: usernameLabel.centerYAnchor)
        ])
    }
    
    func configure(with request: FriendRequest, isIncoming: Bool) {
        usernameLabel.text = request.senderUsername
        
        if isIncoming {
            statusLabel.text = "Wants to be friends"
        } else {
            switch request.status {
            case "pending":
                statusLabel.text = "Request sent"
                statusLabel.textColor = .systemOrange
            case "accepted":
                statusLabel.text = "Request accepted"
                statusLabel.textColor = .systemGreen
            case "declined":
                statusLabel.text = "Request declined"
                statusLabel.textColor = .systemRed
            default:
                statusLabel.text = "Unknown status"
                statusLabel.textColor = .secondaryLabel
            }
        }
        
        let formatter = DateFormatter()
        let date = request.timestamp.dateValue()
        
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
