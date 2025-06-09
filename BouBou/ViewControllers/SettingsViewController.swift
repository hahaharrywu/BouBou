//
//  SettingsViewController.swift
//  BouBou
//
//  Created by Hongrui Wu  on 6/8/25.
//

import UIKit
import Firebase
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

class SettingsViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    

    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var userEmailLabel: UILabel!


    // Flag to make sure we only set avatar corner radius once
    var didSetAvatarCornerRadius = false

    // Selected new avatar image (if user selected one)
    var selectedAvatarImage: UIImage? = nil

    // Selected new background image (if user selected one)
    var selectedBackgroundImage: UIImage? = nil
    
    // Currently updated User Name (user edits this)
    var updatedUserName: String? = nil
    
    // ⭐️ Added: temp variables to hold avatarUrl / backgroundUrl to save in UserProfile
    var avatarUrlToSave: String = ""
    var backgroundUrlToSave: String = ""
    
    
    

    override func viewDidLoad() {
        super.viewDidLoad()

        // Enable user interaction on avatarImageView
        avatarImageView.isUserInteractionEnabled = true
        avatarImageView.image = UIImage(systemName: "person.circle")
        avatarImageView.tintColor = UIColor(red: 200/255, green: 117/255, blue: 95/255, alpha: 1.0)

        let avatarTapGesture = UITapGestureRecognizer(target: self, action: #selector(avatarTapped))
        avatarImageView.addGestureRecognizer(avatarTapGesture)
        
        // Enable user interaction on backgroundImageView
        backgroundImageView.isUserInteractionEnabled = true
        backgroundImageView.image = UIImage(systemName: "photo")
        backgroundImageView.contentMode = .scaleAspectFill

        let backgroundTapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        backgroundImageView.addGestureRecognizer(backgroundTapGesture)
        
        // Enable user interaction on userNameLabel
        userNameLabel.isUserInteractionEnabled = true
        let userNameTapGesture = UITapGestureRecognizer(target: self, action: #selector(userNameTapped))
        userNameLabel.addGestureRecognizer(userNameTapGesture)
        
        
        // Shadow background
        let gradientView = UIView(frame: backgroundImageView.bounds)
        gradientView.translatesAutoresizingMaskIntoConstraints = false

        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.6).cgColor]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.frame = backgroundImageView.bounds
        gradientView.layer.addSublayer(gradientLayer)

        // load upon the background
        backgroundImageView.addSubview(gradientView)
        backgroundImageView.bringSubviewToFront(gradientView)

        // let gradientView auto match backgroundImageView size
        NSLayoutConstraint.activate([
            gradientView.leadingAnchor.constraint(equalTo: backgroundImageView.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: backgroundImageView.trailingAnchor),
            gradientView.topAnchor.constraint(equalTo: backgroundImageView.topAnchor),
            gradientView.bottomAnchor.constraint(equalTo: backgroundImageView.bottomAnchor)
        ])

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
        self.title = "Settings"

        // show user email
        if let user = Auth.auth().currentUser {
            self.userEmailLabel.text = user.email
            print("✅ Displayed current user email: \(user.email ?? "unknown")")

            // load user indo in Firestore
            let db = Firestore.firestore()
            db.collection("users").document(user.uid).getDocument { documentSnapshot, error in
                if let error = error {
                    print("❌ Failed to load user profile from Firestore: \(error.localizedDescription)")
                    return
                }

                guard let document = documentSnapshot, document.exists else {
                    print("❌ Document does not exist.")
                    self.avatarImageView.image = UIImage(named: "Avatar_Cat")
                    self.backgroundImageView.image = UIImage(named: "Background_ElCapitan")
                    self.backgroundImageView.contentMode = .scaleAspectFill
                    self.userNameLabel.text = "Your Name"
                    self.updatedUserName = "Your Name"
                    return
                }

                // avatarUrl
                if let avatarUrlString = document.get("avatarUrl") as? String {
                    let trimmed = avatarUrlString.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let url = URL(string: trimmed) {
                        print("✅ Loaded avatarUrl from Firestore: \(avatarUrlString)")
                        self.avatarUrlToSave = avatarUrlString

                        URLSession.shared.dataTask(with: url) { data, _, error in
                            if let data = data, let image = UIImage(data: data) {
                                DispatchQueue.main.async {
                                    self.avatarImageView.image = image
                                }
                            } else {
                                print("❌ Failed to load avatar image data from URL: \(url.absoluteString)")
                                if let error = error {
                                    print("❌ URLSession error: \(error.localizedDescription)")
                                }
                                DispatchQueue.main.async {
                                    self.avatarImageView.image = UIImage(named: "Avatar_Cat")
                                }
                            }
                        }.resume()
                    } else {
                        print("❌ Invalid avatarUrl string.")
                        self.avatarImageView.image = UIImage(named: "Avatar_Cat")
                    }
                } else {
                    print("ℹ️ No avatarUrl found in Firestore, using default avatar.")
                    self.avatarImageView.image = UIImage(named: "Avatar_Cat")
                    self.avatarUrlToSave = ""
                }

                // backgroundUrl
                if let backgroundUrlString = document.get("backgroundUrl") as? String {
                    let trimmed = backgroundUrlString.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let url = URL(string: trimmed) {
                        print("✅ Loaded backgroundUrl from Firestore: \(backgroundUrlString)")
                        self.backgroundUrlToSave = backgroundUrlString

                        URLSession.shared.dataTask(with: url) { data, _, error in
                            if let data = data, let image = UIImage(data: data) {
                                DispatchQueue.main.async {
                                    self.backgroundImageView.image = image
                                }
                            } else {
                                print("❌ Failed to load background image data from URL: \(url.absoluteString)")
                                if let error = error {
                                    print("❌ URLSession error: \(error.localizedDescription)")
                                }
                                DispatchQueue.main.async {
                                    self.backgroundImageView.image = UIImage(named: "Background_ElCapitan")
                                    self.backgroundImageView.contentMode = .scaleAspectFill
                                }
                            }
                        }.resume()
                    } else {
                        print("❌ Invalid backgroundUrl string.")
                        self.backgroundImageView.image = UIImage(named: "Background_ElCapitan")
                        self.backgroundImageView.contentMode = .scaleAspectFill
                    }
                } else {
                    print("ℹ️ No backgroundUrl found in Firestore, using default background.")
                    self.backgroundImageView.image = UIImage(named: "Background_ElCapitan")
                    self.backgroundImageView.contentMode = .scaleAspectFill
                    self.backgroundUrlToSave = ""
                }

                // username
                if let username = document.get("username") as? String {
                    print("✅ Loaded username from Firestore: \(username)")
                    self.userNameLabel.text = username
                    self.updatedUserName = username
                } else {
                    print("ℹ️ No username found in Firestore, using default.")
                    self.userNameLabel.text = "Your Name"
                    self.updatedUserName = "Your Name"
                }
            }
        }
    }

    
    
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if !didSetAvatarCornerRadius {
            avatarImageView.layer.cornerRadius = avatarImageView.frame.width / 2
            avatarImageView.clipsToBounds = true
            avatarImageView.contentMode = .scaleAspectFill

            didSetAvatarCornerRadius = true
            print("✅ Avatar imageView is now circular.")
        }
    }

    @objc func avatarTapped() {
        print("👤 Avatar tapped")
        let actionSheet = UIAlertController(title: "Change Avatar", message: "Choose a source", preferredStyle: .actionSheet)

        actionSheet.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: { _ in
            self.presentImagePicker(sourceType: .photoLibrary)
        }))
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { _ in
            self.presentImagePicker(sourceType: .camera)
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.sourceView = avatarImageView
            popoverController.sourceRect = avatarImageView.bounds
        }

        present(actionSheet, animated: true)
    }

    func presentImagePicker(sourceType: UIImagePickerController.SourceType) {
        if UIImagePickerController.isSourceTypeAvailable(sourceType) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = sourceType
            imagePicker.allowsEditing = true
            imagePicker.view.tag = 0 // Avatar picker
            present(imagePicker, animated: true)
        } else {
            print("❌ Source type \(sourceType) is not available.")
        }
    }

    @objc func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        if let selectedImage = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {

            if picker.view.tag == 999 {
                backgroundImageView.image = selectedImage
                selectedBackgroundImage = selectedImage
                print("✅ Got background image, uploading to Firebase...")

                uploadImageToStorage(image: selectedImage, path: "backgrounds") { url in
                    if let url = url {
                        self.backgroundUrlToSave = url
                        self.updateUserProfileField(key: "backgroundUrl", value: url)
                    }
                }
            } else {
                avatarImageView.image = selectedImage
                selectedAvatarImage = selectedImage
                print("✅ Got avatar image, uploading to Firebase...")

                uploadImageToStorage(image: selectedImage, path: "avatars") { url in
                    if let url = url {
                        self.avatarUrlToSave = url
                        self.updateUserProfileField(key: "avatarUrl", value: url)
                    }
                }
            }

        } else {
            print("❌ Could not get image.")
        }

        picker.dismiss(animated: true)
    }

    @objc func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        print("⚠️ User canceled image picking.")
    }

    @objc func backgroundTapped() {
        print("🖼️ Background tapped")
        let actionSheet = UIAlertController(title: "Change Background", message: "Choose a source", preferredStyle: .actionSheet)

        actionSheet.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: { _ in
            self.presentImagePickerForBackground(sourceType: .photoLibrary)
        }))
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { _ in
            self.presentImagePickerForBackground(sourceType: .camera)
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.sourceView = backgroundImageView
            popoverController.sourceRect = backgroundImageView.bounds
        }

        present(actionSheet, animated: true)
    }

    func presentImagePickerForBackground(sourceType: UIImagePickerController.SourceType) {
        if UIImagePickerController.isSourceTypeAvailable(sourceType) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = sourceType
            imagePicker.allowsEditing = true
            imagePicker.view.tag = 999 // Background picker
            present(imagePicker, animated: true)
        } else {
            print("❌ Source type \(sourceType) is not available.")
        }
    }

    @objc func userNameTapped() {
        print("📝 User Name tapped")
        let alertController = UIAlertController(title: "Edit User Name", message: "Enter your new user name (max 9 words)", preferredStyle: .alert)

        alertController.addTextField { textField in
            textField.placeholder = "User Name"
            textField.text = self.userNameLabel.text
            textField.autocapitalizationType = .words
        }

        let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
            if let textField = alertController.textFields?.first,
               let newUserName = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
               !newUserName.isEmpty {

                let wordCount = newUserName.split(separator: " ").count
                if wordCount <= 9 {
                    print("✅ New User Name accepted: \(newUserName)")
                    self.userNameLabel.text = newUserName
                    self.updatedUserName = newUserName
                    self.updateUserProfileField(key: "username", value: newUserName)
                } else {
                    print("❌ User Name exceeds 9 words")
                    self.showErrorAlert(message: "User Name cannot exceed 9 words.")
                }
            } else {
                print("❌ Empty User Name not allowed")
                self.showErrorAlert(message: "User Name cannot be empty.")
            }
        }

        alertController.addAction(saveAction)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alertController, animated: true)
    }

    func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Invalid User Name", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true)
    }
    
    // ⭐️ Helper function to upload image to Storage and update corresponding URL
    func uploadImageToStorage(image: UIImage, path: String, completion: @escaping (String?) -> Void) {
        guard let user = Auth.auth().currentUser,
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Failed to prepare image data.")
            completion(nil)
            return
        }

        let storageRef = Storage.storage().reference().child("\(path)/\(user.uid).jpg")

        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                print("❌ Failed to upload \(path): \(error.localizedDescription)")
                completion(nil)
                return
            }

            storageRef.downloadURL { url, error in
                if let error = error {
                    print("❌ Failed to get \(path) download URL: \(error.localizedDescription)")
                    completion(nil)
                    return
                }

                if let downloadURL = url {
                    print("✅ \(path) uploaded. Download URL: \(downloadURL.absoluteString)")
                    completion(downloadURL.absoluteString)
                } else {
                    completion(nil)
                }
            }
        }
    }


    func updateUserProfileField(key: String, value: Any) {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        
        db.collection("users").document(user.uid).setData([key: value], merge: true) { error in
            if let error = error {
                print("❌ Failed to update \(key): \(error.localizedDescription)")
            } else {
                print("✅ \(key) updated to Firestore.")
            }
        }
    }

    
    
    // Called when user taps Log Out button
    @IBAction func logOutButtonTapped(_ sender: UIButton) {
        print("🚪 Log Out button tapped.")
        
        do {
            // Attempt to sign out user
            try Auth.auth().signOut()
            print("✅ Successfully logged out.")
            
            // Return to Login screen
            if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginViewController")
                sceneDelegate.window?.rootViewController = loginVC
            }
        } catch let signOutError as NSError {
            print("❌ Error signing out: %@", signOutError)
        }
    }
}
