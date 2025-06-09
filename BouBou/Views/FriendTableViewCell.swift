//
//  FriendTableViewCell.swift
//  BouBou
//
//  Created by Hongrui Wu  on 6/9/25.
//

import UIKit

class FriendTableViewCell: UITableViewCell {
    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var commentLabel: UILabel!
    @IBOutlet weak var optionsButton: UIButton!
    
    var optionsButtonAction: (() -> Void)?

    @IBAction func optionsButtonTapped(_ sender: UIButton) {
        optionsButtonAction?()
    }
}
