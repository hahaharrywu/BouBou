//
//  FeedTableViewCell.swift
//  BouBou
//
//  Created by Hongrui Wu  on 5/30/25.
//

import UIKit

class FeedTableViewCell: UITableViewCell {

    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var optionsButton: UIButton!
    @IBOutlet weak var sendImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var sendInfoLabel: UILabel!
    @IBOutlet weak var summaryLabel: UILabel!
    @IBOutlet weak var feelingLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var isSharedLabel: UILabel!
    

    
    @IBAction func optionsButtonTapped(_ sender: UIButton) {
        print("🍔 Options button tapped")
        optionsButtonAction?()
    }

    // Closure property to notify FeedViewController when options button is tapped
    var optionsButtonAction: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Add rounded corners to the feelingLabel
        feelingLabel.layer.cornerRadius = 8
        feelingLabel.layer.masksToBounds = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        // avatar round corner
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.layer.cornerRadius = avatarImageView.frame.height / 2
        avatarImageView.clipsToBounds = true
        
        // send image corner
        sendImageView.contentMode = .scaleAspectFill
        sendImageView.layer.cornerRadius = 12
        sendImageView.clipsToBounds = true
    }
}
