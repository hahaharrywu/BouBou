//
//  AddFriendsViewController.swift
//  BouBou
//
//  Created by Hongrui Wu  on 6/9/25.
//

import UIKit
import FirebaseFirestore
import FirebaseAuth

class AddFriendsViewController: UIViewController {
    
    
    @IBOutlet weak var emailTextField: UITextField!

    @IBAction func addButtonTapped(_ sender: UIButton) {
        let email = emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        guard !email.isEmpty else {
            showAlert(title: "Error", message: "Please enter an email.")
            return
        }

        searchAndAddFriend(with: email)
    }

    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    
    func searchAndAddFriend(with email: String) {
        let db = Firestore.firestore()
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            self.showAlert(title: "Error", message: "User not logged in.")
            return
        }

        // Trim and lowercase email input
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Search for user by email
        db.collection("users").whereField("email", isEqualTo: trimmedEmail).getDocuments { snapshot, error in
            if let error = error {
                self.showAlert(title: "Error", message: error.localizedDescription)
                return
            }

            guard let documents = snapshot?.documents, let doc = documents.first else {
                self.showAlert(title: "Not Found", message: "No user found with that email.")
                return
            }

            let foundUserId = doc.documentID

            // Prevent user from following themselves
            if foundUserId == currentUserId {
                self.showAlert(title: "Error", message: "You cannot follow yourself.")
                return
            }

            // Define document reference for the follow record
            let followDocRef = db.collection("users")
                .document(currentUserId)
                .collection("following")
                .document(foundUserId)

            // Check if already following
            followDocRef.getDocument { followSnapshot, error in
                if let followSnapshot = followSnapshot, followSnapshot.exists {
                    self.showAlert(title: "Info", message: "You already follow this user.")
                    return
                }

                // Save follow record with timestamp and optional comment
                followDocRef.setData([
                    "timestamp": FieldValue.serverTimestamp(),
                    "comment": ""  // Optional: you can allow user to enter a note here
                ]) { error in
                    if let error = error {
                        self.showAlert(title: "Error", message: error.localizedDescription)
                    } else {
                        self.showAlert(title: "Success", message: "Friend added!") {
                            self.navigationController?.popViewController(animated: true)
                        }
                    }
                }
            }
        }
    }

    

    func showAlert(title: String, message: String, onDismiss: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            onDismiss?()
        })
        present(alert, animated: true)
    }
}
