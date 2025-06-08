//
//  SendRecord.swift
//  BouBou
//
//  Created by Haiyi Luo on 6/8/25.
//

import Foundation
import FirebaseFirestore

struct SendRecord {
    let documentID: String
    let color: String
    let grade: String
    let status: String
    let attempts: String
    let feeling: String
    let imageUrl: String
    let userId: String
    let userName: String
    let userEmail: String
    let timestamp: Timestamp
    let isShared: Bool
    
    // Initialize from Firebase document dictionary
    init(documentID: String, dict: [String: Any]) {
        self.documentID = documentID
        self.color = dict["color"] as? String ?? "Color"
        self.grade = dict["grade"] as? String ?? "V?"
        self.status = dict["status"] as? String ?? ""
        self.attempts = dict["attempts"] as? String ?? "?"
        self.feeling = dict["feeling"] as? String ?? ""
        self.imageUrl = dict["imageUrl"] as? String ?? ""
        self.userId = dict["userId"] as? String ?? ""
        self.userName = dict["userName"] as? String ?? ""
        self.userEmail = dict["userEmail"] as? String ?? "unknown@example.com"
        self.timestamp = dict["timestamp"] as? Timestamp ?? Timestamp()
        self.isShared = dict["isShared"] as? Bool ?? false
    }
}
