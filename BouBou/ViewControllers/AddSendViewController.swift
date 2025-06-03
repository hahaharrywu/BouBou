import UIKit
import Firebase
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

class AddSendViewController: UIViewController,
                              UIImagePickerControllerDelegate,
                              UINavigationControllerDelegate,UITextFieldDelegate{

    // Stack View that wraps the "Color" label and icon
    // We add a gesture recognizer to this entire stack to detect taps
    @IBOutlet weak var colorStackView: UIStackView!
    
    // The label that displays the selected climbing color (e.g., "Red", "Blue")
    @IBOutlet weak var colorLabel: UILabel!
    
    // Label used to display the selected climbing grade (e.g., V3, V7)
    @IBOutlet weak var gradeLabel: UILabel!

    // Stack view that contains the grade label and icon, used for click detection
    @IBOutlet weak var gradeStackView: UIStackView!

    // Image view that shows the photo added by the user
    @IBOutlet weak var sendImageView: UIImageView!
    
    // Stack View for triggering the Status dropdown
    @IBOutlet weak var statusPopupStackView: UIStackView!

    // Label that displays the selected Status
    @IBOutlet weak var statusLabel: UILabel!

    // Stack View for triggering the Attempts dropdown
    @IBOutlet weak var attemptsPopupStackView: UIStackView!

    // Label that displays the selected Attempts value
    @IBOutlet weak var attemptsLabel: UILabel!

    // Field for user to input short feelings (title-style)
    @IBOutlet weak var feelingTextField: UITextField!
    
    // A reference to the Save button, used for enabling/disabling or updating text
    @IBOutlet weak var saveButton: UIButton!

    
    /// Called when user taps the Save button
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        // Grab all current values from the screen
        let color = colorLabel.text ?? "N/A"
        let grade = gradeLabel.text ?? "N/A"
        let status = statusLabel.text ?? "N/A"
        let attempts = attemptsLabel.text ?? "N/A"
        let feeling = feelingTextField.text ?? ""
        let timestamp = Date()

        // If there's an image, upload it first
        if let image = sendImageView.image {
            uploadImageToFirebase(image) { imageUrl in
                let url = imageUrl ?? "" // fallback to empty string

                // Create a Send object
                let send = Send(color: color,
                                grade: grade,
                                status: status,
                                attempts: attempts,
                                feeling: feeling,
                                imageUrl: url,
                                timestamp: timestamp)

                // Save to Firestore
                self.saveSendToFirestore(send)
            }
        }
    }



    override func viewDidLoad() {
        super.viewDidLoad()

        // Set a default placeholder image
        sendImageView.image = UIImage(systemName: "photo")

        // Allow tapping anywhere to dismiss the keyboard
        setupKeyboardDismissRecognizer()

        // Add a gesture recognizer to the entire colorStackView
        // So user can tap on "Color" label or chevron to trigger dropdown
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(colorStackTapped))
        colorStackView.addGestureRecognizer(tapGesture)
        
        // Create a tap gesture recognizer for grade selection
        let gradeTapGesture = UITapGestureRecognizer(target: self, action: #selector(gradeStackTapped))

        // Add the gesture to the grade stack view
        gradeStackView.addGestureRecognizer(gradeTapGesture)
        
        // Enable status dropdown trigger
        let statusTapGesture = UITapGestureRecognizer(target: self, action: #selector(statusStackTapped))
        statusPopupStackView.addGestureRecognizer(statusTapGesture)

        // Enable attempts dropdown trigger
        let attemptsTapGesture = UITapGestureRecognizer(target: self, action: #selector(attemptsStackTapped))
        attemptsPopupStackView.addGestureRecognizer(attemptsTapGesture)
        
        // Add tap gesture to the image view for uploading photo
        let imageTapGesture = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        sendImageView.addGestureRecognizer(imageTapGesture)

        // Set the placeholder text shown when the field is empty
        feelingTextField.placeholder = "Say something here~"

        // Show a clear (X) button on the right when editing
        // Allows the user to quickly clear the text
        feelingTextField.clearButtonMode = .whileEditing

        // Change the return key to "Done" instead of "Return"
        feelingTextField.returnKeyType = .done

        // Set this view controller as the delegate so we can handle
        // actions like pressing return or responding to editing events
        feelingTextField.delegate = self
    }

    // Set up gesture recognizer to dismiss keyboard when tapping outside
    func setupKeyboardDismissRecognizer() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }

    // Dismiss the keyboard
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    // Called when the user taps anywhere inside the colorStackView
    @objc func colorStackTapped() {
        showColorDropdown()
    }

    // Show a scrollable dropdown menu for selecting climbing color
    func showColorDropdown() {
        let alert = UIAlertController(title: "Choose Color", message: nil, preferredStyle: .alert)

        // Common bouldering colors
        let colors = ["Red", "Blue", "Green", "Yellow", "Purple", "Orange",
                      "Black", "White", "Pink", "Gray", "Brown"]

        // Add each color option to the alert
        for color in colors {
            let action = UIAlertAction(title: color, style: .default) { _ in
                // Update the label text to the selected color
                self.colorLabel.text = color
            }
            alert.addAction(action)
        }

        // Add a cancel option
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        // iPad fix to anchor the alert properly
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX,
                                        y: self.view.bounds.midY,
                                        width: 0, height: 0)
        }

        // Present the dropdown
        present(alert, animated: true, completion: nil)
    }
    
    
    // Called when the user taps on the grade stack view to select a V-grade
    @objc func gradeStackTapped() {
        let alert = UIAlertController(title: "Choose Grade", message: nil, preferredStyle: .alert)

        // Grades from V1 to V15
        let grades = (1...15).map { "V\($0)" }

        // Add each grade as an option
        for grade in grades {
            let action = UIAlertAction(title: grade, style: .default) { _ in
                // Update the label text when a grade is selected
                self.gradeLabel.text = grade
                self.gradeLabel.textAlignment = .center // Keep it centered
            }
            alert.addAction(action)
        }

        // Cancel option
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        // iPad fix
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX,
                                        y: self.view.bounds.midY,
                                        width: 0, height: 0)
        }

        // Present the dropdown-style alert
        present(alert, animated: true, completion: nil)
    }
    
    // Called when the user taps on the Status Stack
    @objc func statusStackTapped() {
        let alert = UIAlertController(title: "Choose Status", message: nil, preferredStyle: .actionSheet)

        // Status options ordered by climbing difficulty level
        let statusOptions = [
            ("Onsight", "no info, first try"),
            ("Flash", "with info, first try"),
            ("Send", "finished after tries"),
            ("Projecting", "still trying"),
            ("Fail", "didn’t finish this time")
        ]

        for (status, explanation) in statusOptions {
            let title = "\(status) (\(explanation))"
            let action = UIAlertAction(title: title, style: .default) { _ in
                // Update label with chosen status only (no explanation)
                self.statusLabel.text = status
                self.statusLabel.textAlignment = .center
                self.statusLabel.textColor = .label // Turn from gray to black
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
        }

        present(alert, animated: true)
    }
    
    // Called when the user taps on the Attempts Stack
    @objc func attemptsStackTapped() {
        let alert = UIAlertController(title: "Choose Attempts", message: nil, preferredStyle: .actionSheet)

        // Simple options
        let attemptOptions = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "10+"]

        for option in attemptOptions {
            let action = UIAlertAction(title: option, style: .default) { _ in
                if option == "10+" {
                    self.showCustomAttemptInput()
                } else {
                    self.attemptsLabel.text = option
                    self.attemptsLabel.textAlignment = .center
                    self.attemptsLabel.textColor = .label // Turn from gray to black
                }
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
        }

        present(alert, animated: true, completion: nil)
    }
    
    // Show a prompt to let user enter their own attempt count
    func showCustomAttemptInput() {
        let inputAlert = UIAlertController(title: "Enter Attempts", message: "Type how many tries you took", preferredStyle: .alert)

        inputAlert.addTextField { textField in
            textField.placeholder = "Enter a number (e.g. 14)"
            textField.keyboardType = .numberPad
        }

        let confirm = UIAlertAction(title: "OK", style: .default) { _ in
            if let text = inputAlert.textFields?.first?.text, !text.isEmpty {
                self.attemptsLabel.text = text
                self.attemptsLabel.textAlignment = .center
                self.attemptsLabel.textColor = .label // Turn from gray to black
            }
        }

        let cancel = UIAlertAction(title: "Cancel", style: .cancel)

        inputAlert.addAction(confirm)
        inputAlert.addAction(cancel)

        present(inputAlert, animated: true, completion: nil)
    }
    
    // Called when the user taps the image view to upload a photo
    @objc func imageTapped() {
        let alert = UIAlertController(title: "Upload Image", message: nil, preferredStyle: .actionSheet)

        // Choose from photo library
        alert.addAction(UIAlertAction(title: "Choose from Library", style: .default) { _ in
            self.presentImagePicker(sourceType: .photoLibrary)
        })

        // Take a photo (only works on real device)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            alert.addAction(UIAlertAction(title: "Take Photo", style: .default) { _ in
                self.presentImagePicker(sourceType: .camera)
            })
        }

        // Cancel option
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        // iPad fix
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX,
                                        y: self.view.bounds.midY,
                                        width: 0, height: 0)
        }

        present(alert, animated: true, completion: nil)
    }
    
    // Open image picker with the selected source type
    func presentImagePicker(sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        picker.allowsEditing = true // Let user crop
        present(picker, animated: true, completion: nil)
    }
    
    // Called when user finishes picking an image
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        // Try to get edited image first, then original
        if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
            sendImageView.image = image
            sendImageView.contentMode = .scaleAspectFill
        }

        dismiss(animated: true, completion: nil)
    }

    // Called when user cancels image selection
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    // When user taps return key on keyboard
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    /// Uploads the selected image to Firebase Storage and returns the download URL
    /// - Parameters:
    ///   - image: the UIImage to upload
    ///   - completion: closure returning the image URL or an error
    func uploadImageToFirebase(_ image: UIImage, completion: @escaping (String?) -> Void) {
        
        // Convert image to JPEG data (compression: 0.8 = good balance)
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Failed to convert image to data.")
            completion(nil)
            return
        }

        // Generate unique filename using timestamp
        let fileName = "sends/\(UUID().uuidString).jpg"

        // Create a reference in Firebase Storage
        let storageRef = Storage.storage().reference().child(fileName)

        // Upload the image data
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                print("❌ Image upload failed: \(error)")
                completion(nil)
                return
            }

            // Get download URL after successful upload
            storageRef.downloadURL { url, error in
                if let url = url {
                    print("✅ Image uploaded successfully: \(url.absoluteString)")
                    completion(url.absoluteString)
                } else {
                    print("❌ Failed to retrieve image URL: \(error?.localizedDescription ?? "unknown error")")
                    completion(nil)
                }
            }
        }
    }
    
    /// Saves the Send object to Firebase Firestore
    /// - Parameter send: the Send instance containing user-submitted data
    func saveSendToFirestore(_ send: Send) {
        let db = Firestore.firestore()
        
        // Obtaining the UID of the current user
        let userID = Auth.auth().currentUser?.uid ?? "unknown"

        // Prepare dictionary from Send struct
        let sendData: [String: Any] = [
            "userId": userID,
            "color": send.color,
            "grade": send.grade,
            "status": send.status,
            "attempts": send.attempts,
            "feeling": send.feeling,
            "imageUrl": send.imageUrl,
            "timestamp": Timestamp(date: send.timestamp)
        ]

        // Save to 'sends' collection
        db.collection("sends").addDocument(data: sendData) { error in
            if let error = error {
                print("❌ Failed to save send: \(error.localizedDescription)")
            } else {
                print("✅ Send saved to Firestore!")
            }
        }
    }
}

// MARK: - Data model
// A simple struct to represent a climbing send record
struct Send {
    // The selected climbing color (e.g., Red, Blue)
    var color: String

    // The grade of the climb (e.g., V5)
    var grade: String

    // Status like Flash, Onsight, etc.
    var status: String

    // Attempts made (e.g., "1", "10+")
    var attempts: String

    // Short user note or feeling
    var feeling: String

    // The Firebase image URL (will be set after upload)
    var imageUrl: String

    // Timestamp of when the send was created
    var timestamp: Date
}
