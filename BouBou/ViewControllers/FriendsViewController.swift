//
//  FriendsViewController.swift
//  BouBou
//
//  Created by Hongrui Wu  on 6/9/25.
//

import UIKit

class FriendsViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func didTapRequestsButton(_ sender: UIBarButtonItem) {
        performSegue(withIdentifier: "goToFriendRequests", sender: self)
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
