//
//  FeedViewController.swift
//  BouBou
//
//  Created by Hongrui Wu  on 5/30/25.
//

import UIKit
import Firebase
import FirebaseAuth

// This struct represents one send record fetched from Firebase to display in the feed
struct FeedSend {
    let documentID: String // 🔥 New: needed for delete/update
    let color: String
    let grade: String
    let status: String
    let attempts: String
    let feeling: String
    let imageUrl: String
    let userId: String
    let userName: String // New field: Will be email prefix for now
    let userEmail: String // New field: user email (optional, not displayed)
    let timestamp: Timestamp
    let isShared: Bool // ⭐️ NEW FIELD, from Firestore

    // Combines color and grade into Color-V# format for Send Info Label
    var colorGrade: String {
        return "\(color)-\(grade)"
    }
    
    // Initialize from Firebase document dictionary
    init(documentID: String, dict: [String: Any]) {
        self.documentID = documentID
        self.color = dict["color"] as? String ?? "Color"
        self.grade = dict["grade"] as? String ?? "V?"
        self.status = dict["status"] as? String ?? ""
        self.attempts = dict["attempts"] as? String ?? "?"
        self.feeling = dict["feeling"] as? String ?? ""
        self.imageUrl = dict["imageUrl"] as? String ?? ""
        self.userId = dict["userId"] as? String ?? ""
        self.userName = dict["userName"] as? String ?? ""
        self.userEmail = dict["userEmail"] as? String ?? "unknown@example.com"
        self.timestamp = dict["timestamp"] as? Timestamp ?? Timestamp()
        self.isShared = dict["isShared"] as? Bool ?? false
    }
}



class FeedViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Feed Mode Enum (World or Me tab)
    enum FeedMode {
        case world    // World tab → show isShared == true posts
        case me       // Me tab → show current user's posts (shared + unshared)
    }

    // Current selected feed mode (default is World)
    var selectedMode: FeedMode = .world
    
    // The initial mode passed from AddSend screen.
    // If set, FeedViewController will show this mode first (World or Me).
    // After using this value, it will be cleared to avoid reapplying.
    var initialMode: FeedMode? = nil
    
    // Simple image cache: URL string → UIImage
    var imageCache = NSCache<NSString, UIImage>()

    // Existing sends array
    var sends: [FeedSend] = []
    
    @IBOutlet weak var segmentedControl: UISegmentedControl!

    
    // MARK: - Segmented Control Action
    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            print("🌍 World selected")
            selectedMode = .world
        } else {
            print("👤 Me selected")
            selectedMode = .me
        }
        
        // Reload data according to new selectedMode
        fetchData()
    }

    @IBOutlet weak var tableView: UITableView!
    
    //let testData = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]

    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("🌀 FeedViewController viewDidLoad called")
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.showsVerticalScrollIndicator = false
        
        // Add pull-to-refresh control
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
        // No need to call fetchData() here anymore
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        print("🌀 FeedViewController viewWillAppear called")
        
        // If initialMode is set (from AddSend), apply it to selectedMode and segmented control
        if let mode = initialMode {
            selectedMode = mode
            print("🎯 Applying initialMode = \(mode)")
            segmentedControl.selectedSegmentIndex = (mode == .world) ? 0 : 1
            print("🎯 SegmentedControl updated to \(mode == .world ? "World" : "Me")")
            // Clear initialMode after applying it once
            initialMode = nil
        }
        
        // Now fetch data for the selected mode
        fetchData()
    }
    
    // Load send records from Firestore and update the table view
    // MARK: - Fetch Data from Firestore based on selectedMode
    func fetchData() {
        let db = Firestore.firestore()

        // Start with base query sorted by timestamp
        var query: Query = db.collection("sends")
            .order(by: "timestamp", descending: true)

        // Modify query depending on selectedMode (World or Me)
        switch selectedMode {
        case .world:
            print("🌍 Fetching World posts...")
            // World tab → show only posts where isShared == true
            query = query.whereField("isShared", isEqualTo: true)

        case .me:
            print("👤 Fetching Me posts...")
            // Me tab → show only posts from current user (isShared true/false both included)
            let currentUserId = Auth.auth().currentUser?.uid ?? "unknown"
            query = query.whereField("userId", isEqualTo: currentUserId)
        }

        // Execute the Firestore query
        query.getDocuments { snapshot, error in
            if let error = error {
                print("❌ Failed to load sends: \(error.localizedDescription)")
                return
            }

            // Convert documents to FeedSend objects
            self.sends = snapshot?.documents.compactMap {
                let data = $0.data()
                let send = FeedSend(documentID: $0.documentID, dict: data)
                print("📥 Fetched send with documentID: \(send.documentID), imageUrl: \(send.imageUrl), isShared: \(send.isShared)")
                return send
            } ?? []


            // Reload the table view on the main thread
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sends.count
    }

    // Configure the appearance of each feed row
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "FeedCell", for: indexPath) as? FeedTableViewCell else {
            return UITableViewCell()
        }

        let send = sends[indexPath.row] // Get the Send object for this row

        // Determine display name based on userName and fallback to email prefix if needed
        let displayName: String
        if send.userName.isEmpty {
            // If userName is empty, fallback to email prefix (before "@")
            displayName = send.userEmail.components(separatedBy: "@").first ?? "unknown"
        } else {
            // If userName is not empty, use it directly
            displayName = send.userName
        }

        // Set the name label to the display name
        cell.nameLabel.text = displayName

        // Set Send Info Label as "Color-V#" (example: "Red-V3")
        cell.sendInfoLabel.text = send.colorGrade

        // Set Summary Label as custom phrase based on status + attempts
        cell.summaryLabel.text = summaryPhrase(for: send.status, attempts: send.attempts)
        
        // Helper function to generate short summary phrase based on status and attempts
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

        // Show the user's comment/feeling
        cell.feelingLabel.text = send.feeling
        
        //Convert Firestore timestamp to Date
        let date = send.timestamp.dateValue()

        //Create DateFormatter
        let dateFormatter = DateFormatter()

        //Use current locale and timezone
        dateFormatter.locale = Locale.current
        dateFormatter.timeZone = TimeZone.current

        //Set desired display format → example: "2025-06-08 00:21"
        dateFormatter.dateFormat = "MM-dd-yyyy HH:mm"

        //Format the date to string
        let dateString = dateFormatter.string(from: date)

        //Set to dateLabel
        cell.dateLabel.text = dateString


        // Set a default avatar image
        cell.avatarImageView.image = UIImage(systemName: "person.circle")

        // Load the send image from URL (if any)
        if let url = URL(string: send.imageUrl), !send.imageUrl.isEmpty {
            
            // 有用户上传 → 圆角 + scaleAspectFill
            cell.sendImageView.layer.cornerRadius = 12
            cell.sendImageView.layer.masksToBounds = true
            cell.sendImageView.clipsToBounds = true
            cell.sendImageView.contentMode = .scaleAspectFill
            print("🖼️ Loading image from URL: \(send.imageUrl)")
            loadImage(with: url, into: cell.sendImageView)
        } else {
            // 没有上传 → SF Symbol 也保持圆角 + scaleAspectFit
            print("🖼️ No image URL, showing default photo.")
            cell.sendImageView.image = UIImage(systemName: "photo")
            cell.sendImageView.layer.cornerRadius = 12
            cell.sendImageView.layer.masksToBounds = true
            cell.sendImageView.clipsToBounds = true
            cell.sendImageView.contentMode = .scaleAspectFit
        }
        
        cell.optionsButtonAction = { [weak self] in
            guard let self = self else { return }
            
            // Get the send associated with this cell
            let send = self.sends[indexPath.row]
            print("🍔 Options tapped for send by \(send.userName), isShared = \(send.isShared)")
            
            // Create the options menu
            let alert = UIAlertController(title: "Options", message: nil, preferredStyle: .actionSheet)
            
            // Always add Delete option
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
                print("🗑️ User chose to delete the send")
                
                let db = Firestore.firestore()
                db.collection("sends").document(send.documentID).delete { error in
                    if let error = error {
                        print("❌ Failed to delete send: \(error.localizedDescription)")
                    } else {
                        print("✅ Send deleted successfully")
                        self.fetchData() // Reload after delete
                    }
                }
            }))
            
            // Add different options based on current mode
            switch self.selectedMode {
            case .world:
                alert.addAction(UIAlertAction(title: "Set as Private", style: .default, handler: { _ in
                    print("🔒 User chose to set as private")
                    
                    let db = Firestore.firestore()
                    db.collection("sends").document(send.documentID).updateData(["isShared": false]) { error in
                        if let error = error {
                            print("❌ Failed to set send as private: \(error.localizedDescription)")
                        } else {
                            print("✅ Send set as private")
                            self.fetchData()
                        }
                    }
                }))
                
            case .me:
                alert.addAction(UIAlertAction(title: "Publish to World", style: .default, handler: { _ in
                    print("🌍 User chose to publish to world")
                    let db = Firestore.firestore()
                    db.collection("sends").document(send.documentID).updateData(["isShared": true]) { error in
                        if let error = error {
                            print("❌ Failed to publish send: \(error.localizedDescription)")
                        } else {
                            print("✅ Send published to world")
                            self.fetchData()
                        }
                    }
                }))
            }
            
            // Add Cancel button
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            
            // Present the alert
            self.present(alert, animated: true, completion: nil)
        }

        return cell
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
    }
    
    // Called when user pulls to refresh the Feed
    @objc func refreshPulled() {
        print("🔄 User triggered pull-to-refresh")
        
        // End refresh AFTER fetch finishes → 放进 DispatchQueue.main.async
        fetchData()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.tableView.refreshControl?.endRefreshing()
        }
    }
    
    // Helper function to load image with cache + retry logic
    func loadImage(with url: URL, into imageView: UIImageView, retryCount: Int = 3) {
        let urlString = url.absoluteString as NSString
        
        // First check cache
        if let cachedImage = imageCache.object(forKey: urlString) {
            print("⚡️ Using cached image!")
            DispatchQueue.main.async {
                imageView.image = cachedImage
            }
            return // No need to download again
        }
        
        // Not cached → download
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let data = data, let downloadedImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    print("✅ Image data loaded successfully!")
                    // Save to cache
                    self.imageCache.setObject(downloadedImage, forKey: urlString)
                    // Set image to view
                    imageView.image = downloadedImage
                }
            } else if retryCount > 0 {
                print("❌ Error loading image: \(error?.localizedDescription ?? "unknown error") → retrying... (\(retryCount) left)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.loadImage(with: url, into: imageView, retryCount: retryCount - 1)
                }
            } else {
                print("❌ Failed to load image after retries.")
                DispatchQueue.main.async {
                    imageView.image = UIImage(systemName: "photo") // fallback image
                }
            }
        }.resume()
    }

}
