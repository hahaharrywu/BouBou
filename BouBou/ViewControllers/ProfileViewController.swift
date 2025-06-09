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
    @IBOutlet weak var lastSessionContainerView: UIView!
    @IBOutlet weak var emptyStateLabel: UILabel!
    
    
    
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
    
    
    @IBOutlet weak var lastSessionSubView_1: UIView!
    @IBOutlet weak var lastSessionSubView_2: UIView!
    @IBOutlet weak var lastSessionSubView_3: UIView!
    @IBOutlet weak var lastSessionSubView_4: UIView!
    @IBOutlet weak var lastSessionSubView_5: UIView!
    @IBOutlet weak var lastSessionSubView_6: UIView!
    @IBOutlet weak var lastSessionSubView_7: UIView!
    @IBOutlet weak var lastSessionSubView_8: UIView!
    @IBOutlet weak var lastSessionSubView_9: UIView!
    @IBOutlet weak var lastSessionSubView_10: UIView!
    @IBOutlet weak var lastSessionSubView_11: UIView!
    @IBOutlet weak var lastSessionSubView_12: UIView!
    
    
    @IBOutlet weak var lastSessionGradeLabel_1: UILabel!
    @IBOutlet weak var lastSessionGradeLabel_2: UILabel!
    @IBOutlet weak var lastSessionGradeLabel_3: UILabel!
    @IBOutlet weak var lastSessionGradeLabel_4: UILabel!
    @IBOutlet weak var lastSessionGradeLabel_5: UILabel!
    @IBOutlet weak var lastSessionGradeLabel_6: UILabel!
    @IBOutlet weak var lastSessionGradeLabel_7: UILabel!
    @IBOutlet weak var lastSessionGradeLabel_8: UILabel!
    @IBOutlet weak var lastSessionGradeLabel_9: UILabel!
    @IBOutlet weak var lastSessionGradeLabel_10: UILabel!
    @IBOutlet weak var lastSessionGradeLabel_11: UILabel!
    @IBOutlet weak var lastSessionGradeLabel_12: UILabel!
    
    
    @IBOutlet weak var lastSessionStatusLabel_1: UILabel!
    @IBOutlet weak var lastSessionStatusLabel_2: UILabel!
    @IBOutlet weak var lastSessionStatusLabel_3: UILabel!
    @IBOutlet weak var lastSessionStatusLabel_4: UILabel!
    @IBOutlet weak var lastSessionStatusLabel_5: UILabel!
    @IBOutlet weak var lastSessionStatusLabel_6: UILabel!
    @IBOutlet weak var lastSessionStatusLabel_7: UILabel!
    @IBOutlet weak var lastSessionStatusLabel_8: UILabel!
    @IBOutlet weak var lastSessionStatusLabel_9: UILabel!
    @IBOutlet weak var lastSessionStatusLabel_10: UILabel!
    @IBOutlet weak var lastSessionStatusLabel_11: UILabel!
    @IBOutlet weak var lastSessionStatusLabel_12: UILabel!
    
    
    
    
    
    
    
    
    
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
        
        // update last session
        if let user = Auth.auth().currentUser {
            updateLastSessionGrid(for: user.uid)
        }
        
        // last session tap
        let tap = UITapGestureRecognizer(target: self, action: #selector(showLastSession))
        lastSessionContainerView.addGestureRecognizer(tap)
        lastSessionContainerView.isUserInteractionEnabled = true
        
        // avatar tap
        let avatarTap = UITapGestureRecognizer(target: self, action: #selector(avatarTapped))
        avatarImageView.addGestureRecognizer(avatarTap)
        avatarImageView.isUserInteractionEnabled = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
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
                let sends: [FeedSend] = snapshot?.documents.compactMap { FeedSend(documentID: $0.documentID, dict: $0.data()) } ?? []

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

                let sends = snapshot?.documents.compactMap { FeedSend(documentID: $0.documentID, dict: $0.data()) } ?? []

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

                let sends = snapshot?.documents.compactMap { FeedSend(documentID: $0.documentID, dict: $0.data()) } ?? []
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
    
    
    func updateLastSessionGrid(for userId: String) {
        let db = Firestore.firestore()
        db.collection("sends")
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error: \(error)")
                    return
                }

                let allSends = snapshot?.documents.compactMap {
                    FeedSend(documentID: $0.documentID, dict: $0.data())
                } ?? []

                let subViews = [
                    self.lastSessionSubView_1, self.lastSessionSubView_2, self.lastSessionSubView_3,
                    self.lastSessionSubView_4, self.lastSessionSubView_5, self.lastSessionSubView_6,
                    self.lastSessionSubView_7, self.lastSessionSubView_8, self.lastSessionSubView_9,
                    self.lastSessionSubView_10, self.lastSessionSubView_11, self.lastSessionSubView_12
                ]

                let gradeLabels = [
                    self.lastSessionGradeLabel_1, self.lastSessionGradeLabel_2, self.lastSessionGradeLabel_3,
                    self.lastSessionGradeLabel_4, self.lastSessionGradeLabel_5, self.lastSessionGradeLabel_6,
                    self.lastSessionGradeLabel_7, self.lastSessionGradeLabel_8, self.lastSessionGradeLabel_9,
                    self.lastSessionGradeLabel_10, self.lastSessionGradeLabel_11, self.lastSessionGradeLabel_12
                ]

                let statusLabels = [
                    self.lastSessionStatusLabel_1, self.lastSessionStatusLabel_2, self.lastSessionStatusLabel_3,
                    self.lastSessionStatusLabel_4, self.lastSessionStatusLabel_5, self.lastSessionStatusLabel_6,
                    self.lastSessionStatusLabel_7, self.lastSessionStatusLabel_8, self.lastSessionStatusLabel_9,
                    self.lastSessionStatusLabel_10, self.lastSessionStatusLabel_11, self.lastSessionStatusLabel_12
                ]

                // Empty fallback BEFORE trying to unwrap date
                if allSends.isEmpty {
                    DispatchQueue.main.async {
                        print("📭 No sends found at all. Showing empty state.")

                        for i in 0..<12 {
                            subViews[i]?.isHidden = true
                            gradeLabels[i]?.isHidden = true
                            statusLabels[i]?.isHidden = true
                        }

                        self.emptyStateLabel.isHidden = false
                        self.emptyStateLabel.text = "No sends yet.\nTap Add to start your first session!"
                        self.emptyStateLabel.numberOfLines = 0
                        self.emptyStateLabel.textAlignment = .center
                        
                        // disable tap last session function
                        self.lastSessionContainerView.isUserInteractionEnabled = false
                    }
                    return
                }

                // At least one send exists, continue logic
                guard let latestDate = allSends.first?.timestamp.dateValue() else {
                    print("⚠️ Could not parse latest date from sends.")
                    return
                }

                let calendar = Calendar.current
                let sameDaySends = allSends.filter {
                    calendar.isDate($0.timestamp.dateValue(), inSameDayAs: latestDate)
                }

                let limited = Array(sameDaySends.prefix(12))

                DispatchQueue.main.async {
                    print("📦 Showing last session sends (\(limited.count))")
                    self.emptyStateLabel.isHidden = true

                    for i in 0..<12 {
                        if i < limited.count {
                            let send = limited[i]
                            subViews[i]?.isHidden = false
                            gradeLabels[i]?.isHidden = false
                            statusLabels[i]?.isHidden = false
                            gradeLabels[i]?.text = send.grade.uppercased()

                            switch send.status {
                            case "Onsight", "Flash":
                                statusLabels[i]?.text = "⚡️"
                            case "Fail", "Projecting":
                                statusLabels[i]?.text = "❌"
                            default:
                                statusLabels[i]?.text = "✅"
                            }
                        } else {
                            subViews[i]?.isHidden = false
                            gradeLabels[i]?.text = ""
                            statusLabels[i]?.text = ""
                            gradeLabels[i]?.isHidden = true
                            statusLabels[i]?.isHidden = true
                        }
                    }
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
    
    @objc func showLastSession() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "LastSessionViewController") as? LastSessionViewController {
            vc.modalPresentationStyle = .formSheet // OR .fullScreen, .pageSheet
            self.present(vc, animated: true)
        }
    }
    
    @objc func avatarTapped() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "SettingsViewController")
        self.navigationController?.pushViewController(vc, animated: true)
    }
}
