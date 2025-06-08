//
//  FeedTableViewCell.swift
//  BouBou
//
//  Created by Hongrui Wu  on 5/30/25.
//

import UIKit

class FeedTableViewCell: UITableViewCell {

    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var sendImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var sendInfoLabel: UILabel!
    @IBOutlet weak var summaryLabel: UILabel!
    @IBOutlet weak var feelingLabel: UILabel!
    

    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Add rounded corners to the feelingLabel
        feelingLabel.layer.cornerRadius = 8
        feelingLabel.layer.masksToBounds = true
    }
}
