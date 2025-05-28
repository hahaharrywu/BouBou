//
//  ProfileViewController.swift
//  BouBou
//
//  Created by Hongrui Wu  on 5/25/25.
//

import UIKit

class ProfileViewController: UIViewController {

    
    @IBOutlet weak var avatarImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        // placeholder
        if avatarImageView.image == nil {
                avatarImageView.image = UIImage(systemName: "photo")
        }
    }
    

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // round corner for image
        avatarImageView.layer.cornerRadius = avatarImageView.frame.width / 2
        avatarImageView.clipsToBounds = true
        avatarImageView.contentMode = .scaleAspectFill
    }

}
