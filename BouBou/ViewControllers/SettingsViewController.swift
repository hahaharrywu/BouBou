//
//  SettingsViewController.swift
//  BouBou
//
//  Created by Hongrui Wu  on 6/8/25.
//

import UIKit

class SettingsViewController: UIViewController {
    
    
    

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
        self.title = "Settings"
    }


}
