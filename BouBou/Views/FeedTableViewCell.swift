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
        
        // ⭐️ Add rounded corners to sendImageView (container stays rounded always)
        sendImageView.layer.cornerRadius = 12
        sendImageView.layer.masksToBounds = true
        sendImageView.clipsToBounds = true
        // 不设置 contentMode，这个交给 cellForRowAt 里动态设置（填图片 or SF Symbol）
    }
}
