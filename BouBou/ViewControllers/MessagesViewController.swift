//
//  MessagesViewController.swift
//  BouBou
//
//  Created by An Nguyen on 6/3/25.
//

import UIKit
import Firebase
import FirebaseFirestore
import FirebaseAuth

class MessagesViewController: UIViewController {
    
    @IBOutlet weak var messagesTableView: UITableView!
    @IBOutlet weak var messageInputView: UIView!
    @IBOutlet weak var messageTextField: UITextField!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    
    var chatID: String?
    private var messages: [Message] = []
    private let db = Firestore.firestore()
    private var messagesListener: ListenerRegistration?
    private var currentUserID: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        setupKeyboardObservers()
        getCurrentUserID()
        loadMessages()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        messagesListener?.remove()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupUI() {
        title = "Messages"
        
        messageInputView.layer.borderWidth = 0.5
        messageInputView.layer.borderColor = UIColor.systemGray4.cgColor
        messageInputView.backgroundColor = .systemBackground
        
        messageTextField.placeholder = "Type a message..."
        messageTextField.borderStyle = .roundedRect
        messageTextField.delegate = self
        
        sendButton.setTitle("Send", for: .normal)
        sendButton.backgroundColor = .systemBlue
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.layer.cornerRadius = 8
        sendButton.isEnabled = false
        sendButton.alpha = 0.6
        
        messageTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
    }
    
    private func setupTableView() {
        messagesTableView.delegate = self
        messagesTableView.dataSource = self
        messagesTableView.register(MessageTableViewCell.self, forCellReuseIdentifier: "MessageCell")
        messagesTableView.separatorStyle = .none
        messagesTableView.allowsSelection = false
        messagesTableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        
        messagesTableView.rowHeight = UITableView.automaticDimension
        messagesTableView.estimatedRowHeight = 60
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        messagesTableView.addGestureRecognizer(tapGesture)
    }
    
    private func getCurrentUserID() {
        currentUserID = Auth.auth().currentUser?.uid
    }
    
    private func loadMessages() {
        guard let chatID = chatID else { return }
        
        messagesListener = db.collection("chats")
            .document(chatID)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching messages: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self?.messages = documents.compactMap { document in
                    let data = document.data()
                    return Message(
                        id: document.documentID,
                        text: data["text"] as? String ?? "",
                        senderID: data["senderID"] as? String ?? "",
                        senderName: data["senderName"] as? String ?? "",
                        timestamp: data["timestamp"] as? Timestamp ?? Timestamp()
                    )
                }
                
                DispatchQueue.main.async {
                    self?.messagesTableView.reloadData()
                    self?.scrollToBottom()
                }
            }
    }
    
    private func sendMessage(_ text: String) {
        guard let chatID = chatID,
              let currentUserID = currentUserID,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        db.collection("users").document(currentUserID).getDocument { [weak self] document, error in
            if let error = error {
                print("Error fetching user info: \(error)")
                return
            }
            
            let senderName = document?.data()?["username"] as? String ?? "Unknown"
            
            let messageData: [String: Any] = [
                "text": text,
                "senderID": currentUserID,
                "senderName": senderName,
                "timestamp": Timestamp()
            ]
            
            self?.db.collection("chats")
                .document(chatID)
                .collection("messages")
                .addDocument(data: messageData) { error in
                    if let error = error {
                        print("Error sending message: \(error)")
                    }
                }
            
            self?.db.collection("chats")
                .document(chatID)
                .updateData([
                    "lastMessage": text,
                    "lastMessageTimestamp": Timestamp()
                ])
            
            DispatchQueue.main.async {
                self?.messageTextField.text = ""
                self?.updateSendButtonState()
            }
        }
    }
    
    @IBAction func sendButtonTapped(_ sender: UIButton) {
        guard let text = messageTextField.text else { return }
        sendMessage(text)
    }
    
    @objc private func textFieldDidChange() {
        updateSendButtonState()
    }
    
    private func updateSendButtonState() {
        let hasText = !(messageTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        sendButton.isEnabled = hasText
        sendButton.alpha = hasText ? 1.0 : 0.6
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        
        bottomConstraint.constant = keyboardSize.height - view.safeAreaInsets.bottom
        
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
        
        scrollToBottom()
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        
        bottomConstraint.constant = 0
        
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func scrollToBottom() {
        guard !messages.isEmpty else { return }
        
        DispatchQueue.main.async {
            let indexPath = IndexPath(row: self.messages.count - 1, section: 0)
            self.messagesTableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }
}

extension MessagesViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! MessageTableViewCell
        let message = messages[indexPath.row]
        let isCurrentUser = message.senderID == currentUserID
        
        cell.configure(with: message, isCurrentUser: isCurrentUser)
        return cell
    }
}

extension MessagesViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if sendButton.isEnabled {
            sendButtonTapped(sendButton)
        }
        return true
    }
}

struct Message {
    let id: String
    let text: String
    let senderID: String
    let senderName: String
    let timestamp: Timestamp
}

class MessageTableViewCell: UITableViewCell {
    
    private let bubbleView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 16
        return view
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 16)
        return label
    }()
    
    private let timeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private let senderLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(senderLabel)
        bubbleView.addSubview(messageLabel)
        bubbleView.addSubview(timeLabel)
        
        leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.7),
            
            senderLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            senderLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            senderLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            
            messageLabel.topAnchor.constraint(equalTo: senderLabel.bottomAnchor, constant: 2),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            
            timeLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 4),
            timeLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            timeLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            timeLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(with message: Message, isCurrentUser: Bool) {
        messageLabel.text = message.text
        senderLabel.text = isCurrentUser ? "You" : message.senderName
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        timeLabel.text = formatter.string(from: message.timestamp.dateValue())
        
        if isCurrentUser {
            leadingConstraint.isActive = false
            trailingConstraint.isActive = true
            
            bubbleView.backgroundColor = .systemBlue
            messageLabel.textColor = .white
            senderLabel.textColor = .white.withAlphaComponent(0.8)
            timeLabel.textColor = .white.withAlphaComponent(0.6)
        } else {
            trailingConstraint.isActive = false
            leadingConstraint.isActive = true
            
            bubbleView.backgroundColor = .systemGray5
            messageLabel.textColor = .label
            senderLabel.textColor = .secondaryLabel
            timeLabel.textColor = .tertiaryLabel
        }
    }
}
