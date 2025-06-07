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
    
    
    @IBOutlet weak var v1NumberLabel: UILabel!
    @IBOutlet weak var v2NumberLabel: UILabel!
    @IBOutlet weak var v3NumberLabel: UILabel!
    @IBOutlet weak var v4NumberLabel: UILabel!
    @IBOutlet weak var v5NumberLabel: UILabel!
    @IBOutlet weak var v6NumberLabel: UILabel!
    @IBOutlet weak var v7NumberLabel: UILabel!
    @IBOutlet weak var v8NumberLabel: UILabel!
    @IBOutlet weak var v9NumberLabel: UILabel!
    @IBOutlet weak var v10NumberLabel: UILabel!
    @IBOutlet weak var v11NumberLabel: UILabel!
    @IBOutlet weak var v12NumberLabel: UILabel!
    
    
    
    
    
    
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
        
        // update all sends
        if let user = Auth.auth().currentUser {
            updateGradeCounts(for: user.uid)
        }
        
        // update trend line
        if let user = Auth.auth().currentUser {
            fetchTrendData(for: user.uid) { dataPoints in
                let swiftUIView = TrendChartView(data: dataPoints)
                let hostingController = UIHostingController(rootView: swiftUIView)

                DispatchQueue.main.async {
                    self.addChart(hostingController)
                }
            }
        }
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
            .whereField("userId", isEqualTo: userId)
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

                // abtract double grade（"v4" → 4.0）
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

                // calculate average
                let average = gradeValues.reduce(0, +) / Double(gradeValues.count)
                let rounded = Int(round(average))

                DispatchQueue.main.async {
                    self.currentGradeLabel.text = "V\(rounded)"
                }
            }
    }
    
    func updateGradeCounts(for userId: String) {
        let db = Firestore.firestore()

        db.collection("sends")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Failed to fetch sends: \(error.localizedDescription)")
                    return
                }

                let sends = snapshot?.documents.compactMap { FeedSend(dict: $0.data()) } ?? []

                // initial calculations：grade → count
                var gradeCounts: [Int: Int] = [:]

                for send in sends {
                    let grade = send.grade.lowercased().replacingOccurrences(of: "v", with: "")
                    if let value = Int(grade), value >= 1, value <= 12 {
                        gradeCounts[value, default: 0] += 1
                    }
                }

                DispatchQueue.main.async {
                    // update each label
                    self.v1NumberLabel.text = "\(gradeCounts[1] ?? 0)"
                    self.v2NumberLabel.text = "\(gradeCounts[2] ?? 0)"
                    self.v3NumberLabel.text = "\(gradeCounts[3] ?? 0)"
                    self.v4NumberLabel.text = "\(gradeCounts[4] ?? 0)"
                    self.v5NumberLabel.text = "\(gradeCounts[5] ?? 0)"
                    self.v6NumberLabel.text = "\(gradeCounts[6] ?? 0)"
                    self.v7NumberLabel.text = "\(gradeCounts[7] ?? 0)"
                    self.v8NumberLabel.text = "\(gradeCounts[8] ?? 0)"
                    self.v9NumberLabel.text = "\(gradeCounts[9] ?? 0)"
                    self.v10NumberLabel.text = "\(gradeCounts[10] ?? 0)"
                    self.v11NumberLabel.text = "\(gradeCounts[11] ?? 0)"
                    self.v12NumberLabel.text = "\(gradeCounts[12] ?? 0)"
                }
            }
    }


    func fetchTrendData(for userId: String, completion: @escaping ([DataPoint]) -> Void) {
        let db = Firestore.firestore()
        db.collection("sends")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Failed to fetch sends: \(error.localizedDescription)")
                    completion([])
                    return
                }

                let sends = snapshot?.documents.compactMap { FeedSend(dict: $0.data()) } ?? []
                let calendar = Calendar.current
                let today = Date()

                // Group by week offset (0 = this week, 1 = last week, ..., 23 = 24 weeks ago)
                var weekBuckets: [Int: [Double]] = [:]

                for send in sends {
                    let gradeStr = send.grade.lowercased().replacingOccurrences(of: "v", with: "")
                    guard let grade = Double(gradeStr) else { continue }

                    let sendDate = send.timestamp.dateValue()
                    let components = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: sendDate)
                    guard let sendWeek = calendar.date(from: components),
                          let currentWeek = calendar.date(from: calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: today)) else {
                        continue
                    }

                    let weekOffset = calendar.dateComponents([.weekOfYear], from: sendWeek, to: currentWeek).weekOfYear ?? 0
                    if weekOffset >= 0 && weekOffset < 24 {
                        weekBuckets[weekOffset, default: []].append(grade)
                    }
                }

                // Convert to [DataPoint] from 23 → 0 (oldest to newest)
                var dataPoints: [DataPoint] = []
                for i in (0..<24).reversed() {
                    let weekStartDate = calendar.date(byAdding: .day, value: -7 * (23 - i), to: today)!
                    let grades = weekBuckets[i] ?? []
                    let avg = grades.isEmpty ? 0.0 : grades.reduce(0, +) / Double(grades.count)
                    dataPoints.append(DataPoint(date: weekStartDate, grade: avg))
                }

                completion(dataPoints)
            }
    }


    

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // round corner for image
        avatarImageView.layer.cornerRadius = avatarImageView.frame.width / 2
        avatarImageView.clipsToBounds = true
        avatarImageView.contentMode = .scaleAspectFill
    }
    
    
    func addChart(_ hostingController: UIHostingController<some View>) {
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


}
