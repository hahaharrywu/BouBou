//
//  AddSendViewController.swift
//  BouBou
//
//  Created by Hongrui Wu  on 5/25/25.
//

import UIKit

class AddSendViewController: UIViewController {

    @IBOutlet weak var sendImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        sendImageView.image = UIImage(systemName: "photo")
        
        // disappear keyboard
        setupKeyboardDismissRecognizer()
    }
    

    func setupKeyboardDismissRecognizer() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}
