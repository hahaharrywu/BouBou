//
//  ProfileViewController.swift
//  BouBou
//
//  Created by Hongrui Wu  on 5/25/25.
//

import UIKit
import SwiftUI
import Charts
import Firebase
import FirebaseAuth


class ProfileViewController: UIViewController {

    
    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var chartView: UIView!
    @IBOutlet weak var currentGradeLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        // placeholder
        if avatarImageView.image == nil {
                avatarImageView.image = UIImage(systemName: "photo")
        }
        
        // update my current grade
        if let user = Auth.auth().currentUser {
            updateCurrentGradeLabelFromDatabase(for: user.uid)
        }

        
        let data = generateLastHalfYearData()
        let swiftUIView = TrendChartView(data: data)
        let hostingController = UIHostingController(rootView: swiftUIView)

        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        chartView.backgroundColor = .clear
        chartView.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: chartView.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: chartView.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: chartView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: chartView.trailingAnchor)
        ])

        hostingController.didMove(toParent: self)
    }
    
    func generateLastHalfYearData() -> [DataPoint] {
        let grades: [Double] = [
            1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8,
            2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8,
            1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8
        ]

        var data: [DataPoint] = []
        let calendar = Calendar.current
        let today = Date()

        for i in 0..<24 {
            if let date = calendar.date(byAdding: .day, value: -7 * (23 - i), to: today) {
                data.append(DataPoint(date: date, grade: grades[i]))
            }
        }
        return data
    }
    
    
    func updateCurrentGradeLabelFromDatabase(for userId: String) {
        let db = Firestore.firestore()
        
        db.collection("sends")
            .whereField("userId", isEqualTo: userId) // 只查当前用户
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Failed to fetch sends: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.currentGradeLabel.text = "N/A"
                    }
                    return
                }
                
                // Map documents to FeedSend
                let sends: [FeedSend] = snapshot?.documents.compactMap { FeedSend(dict: $0.data()) } ?? []

                // 提取有效的 Double grade（"v4" → 4.0）
                let gradeValues: [Double] = sends.compactMap { send in
                    let lower = send.grade.lowercased()
                    if lower.hasPrefix("v") {
                        let numberPart = lower.replacingOccurrences(of: "v", with: "")
                        return Double(numberPart)
                    }
                    return nil
                }

                guard !gradeValues.isEmpty else {
                    DispatchQueue.main.async {
                        self.currentGradeLabel.text = "N/A"
                    }
                    return
                }

                // 计算平均 & 更新 UI
                let average = gradeValues.reduce(0, +) / Double(gradeValues.count)
                let rounded = Int(round(average))

                DispatchQueue.main.async {
                    self.currentGradeLabel.text = "V\(rounded)"
                }
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
