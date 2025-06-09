//
//  LoginViewController.swift
//  BouBou
//
//  Created by Hongrui Wu  on 5/25/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class LoginViewController: UIViewController {
    
    
    // Sign up mode boolean
    var isSignUpMode = false
    
    
    
    
    @IBOutlet weak var loginPromptLabel: UILabel!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var forgotPasswordLabel: UILabel!
    @IBOutlet weak var signupPromptLabel: UILabel!
    @IBOutlet weak var forgotPasswordPromptLabel: UILabel!
    @IBOutlet weak var dontHaveAccountPromptLabel: UILabel!
    @IBOutlet weak var whiteBackgroundView: UIView!
    
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    

    override func viewDidLoad() {
        super.viewDidLoad()

        // round corner for login button
//        loginButton.layer.cornerRadius = 8
//        loginButton.clipsToBounds = true
        
        // text fields border
        emailTextField.backgroundColor = .white
        emailTextField.layer.borderWidth = 1
        emailTextField.layer.borderColor = UIColor.lightGray.cgColor
        emailTextField.layer.cornerRadius = 8
        
        passwordTextField.backgroundColor = .white
        passwordTextField.layer.borderWidth = 1
        passwordTextField.layer.borderColor = UIColor.lightGray.cgColor
        passwordTextField.layer.cornerRadius = 8
        
        // tap gesture for signupPromptLabel
        let signupTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSignupTap))
        signupPromptLabel.isUserInteractionEnabled = true
        signupPromptLabel.addGestureRecognizer(signupTapGesture)

        // tap gesture for forgotPasswordPromptLabel
        let forgotPasswordTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleForgotPasswordTap))
        forgotPasswordPromptLabel.isUserInteractionEnabled = true
        forgotPasswordPromptLabel.addGestureRecognizer(forgotPasswordTapGesture)

        
        // white backgound view shadow and round corner
        whiteBackgroundView.layer.cornerRadius = 12
        whiteBackgroundView.layer.shadowColor = UIColor.black.cgColor
        whiteBackgroundView.layer.shadowOpacity = 0.1
        whiteBackgroundView.layer.shadowOffset = CGSize(width: 0, height: 4)
        whiteBackgroundView.layer.shadowRadius = 8
        
        // keyboard type
        emailTextField.keyboardType = .emailAddress
        passwordTextField.keyboardType = .default
        
        // disappear keyboard
        setupKeyboardDismissRecognizer()
    }
    

    
    
    @objc func handleSignupTap() {
        if !isSignUpMode {
            // Switch to Sign Up mode
            loginPromptLabel.text = "Sign up to BouBou"
            loginButton.setTitle("Sign Up", for: .normal)
            forgotPasswordPromptLabel.text = "Already have an account?"
            signupPromptLabel.text = ""
            dontHaveAccountPromptLabel.text = ""
            isSignUpMode = true
        }
    }
    
    
    

    @objc func handleForgotPasswordTap() {
        if isSignUpMode {
            // Switch to Log In mode
            loginPromptLabel.text = "Log in to BouBou"
            loginButton.setTitle("Log In", for: .normal)
            forgotPasswordPromptLabel.text = "Forgot password? "
            dontHaveAccountPromptLabel.text = "Don't have an account?"
            signupPromptLabel.text = "Sign up for BouBou"
            isSignUpMode = false
        } else {
            // send reset email
            sendPasswordReset()
        }
    }
    
    
    
    
    @IBAction func loginButtonTapped(_ sender: UIButton) {
        let email = emailTextField.text ?? ""
        let password = passwordTextField.text ?? ""
        
        if email.isEmpty || password.isEmpty {
            showAlert(title: "Error", message: "Please fill in all fields.")
            return
        }
        
        if isSignUpMode {
            // Sign Up
            Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
                if let error = error {
                    self.showAlert(title: "Sign Up Failed", message: error.localizedDescription)
                    return
                }
                
                // write to Firestore
                if let user = authResult?.user {
                    let db = Firestore.firestore()
                    db.collection("users").document(user.uid).setData([
                        "email": user.email ?? "",
                        "customUserName": "",
                        "avatarUrl": "",
                        "backgroundUrl": ""
                    ], merge: true) { error in
                        if let error = error {
                            print("❌ Failed to write user to Firestore: \(error.localizedDescription)")
                        } else {
                            print("✅ User written to Firestore successfully")
                        }
                    }
                }
                
                self.goToMainScreen()
            }
        } else {
            // Log In → 官方推荐方式 → 直接 signIn → 看 error code 判断
            Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
                if let error = error as NSError? {
                    print("🔥 signIn error: \(error.code) - \(error.localizedDescription)")
                    switch AuthErrorCode(rawValue: error.code) {
                    case .userNotFound:
                        print("🔥 Handling case: userNotFound (Account Not Found)")
                        self.showAlert(title: "Account Not Found", message: "You haven't created an account yet. Please click 'Sign up' below to create one.")
                    case .wrongPassword:
                        print("🔥 Handling case: wrongPassword (Incorrect Password)")
                        self.showAlert(title: "Incorrect Password", message: "The password you entered is incorrect. Please try again.")
                    case .invalidEmail:
                        print("🔥 Handling case: invalidEmail (Invalid Email)")
                        self.showAlert(title: "Invalid Email", message: "The email address is badly formatted. Please check and try again.")
                    case .invalidCredential:
                        print("🔥 Handling case: invalidCredential → treat as Missing Account or Incorrect Password due to EEP")
                        self.showAlert(title: "You don't have an account or wrong password", message: "Please click 'Sign up' below to create an account or try again with a different password.")
                    case .tooManyRequests:
                        print("🔥 Handling case: tooManyRequests (Too Many Attempts)")
                        self.showAlert(title: "Too Many Attempts", message: "Too many unsuccessful login attempts. Please try again later.")
                    default:
                        print("🔥 Unhandled AuthErrorCode: \(AuthErrorCode(rawValue: error.code)?.rawValue ?? -1)")
                        self.showAlert(title: "Log In Failed", message: error.localizedDescription)
                    }
                    return
                }
                
                // 登录成功
                print("✅ Login successful → goToMainScreen")
                self.goToMainScreen()
            }
        }
    }
    
    
    
    
    func goToMainScreen() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let sceneDelegate = windowScene.delegate as? SceneDelegate,
           let window = sceneDelegate.window {
            
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let tabBarController = storyboard.instantiateViewController(withIdentifier: "TabBarController") as! UITabBarController
            window.rootViewController = tabBarController
            window.makeKeyAndVisible()
        }
    }

    
    
    
    
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
    
    
    
    
    func setupKeyboardDismissRecognizer() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }

    
    
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    
    
    
    func sendPasswordReset() {
        guard let email = emailTextField.text, !email.isEmpty else {
            showAlert(title: "Reset Password", message: "Please enter your email address.")
            return
        }
        
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                self.showAlert(title: "Error", message: "Error: \(error.localizedDescription)")
            } else {
                self.showAlert(title: "Send Success", message: "Password reset email sent. Please check your inbox.")
            }
        }
    }
}
