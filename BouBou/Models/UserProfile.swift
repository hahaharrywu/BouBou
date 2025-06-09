//
//  UserProfile.swift
//  BouBou
//
//  Created by Hongrui Wu  on 6/8/25.
//


struct UserProfile {
    let userId: String
    let username: String
    let email: String
    let avatarUrl: String
    let backgroundUrl: String

    init(documentID: String, dict: [String: Any]) {
        self.userId = documentID
        self.username = dict["username"] as? String ?? ""
        self.email = dict["email"] as? String ?? ""
        self.avatarUrl = dict["avatarUrl"] as? String ?? ""
        self.backgroundUrl = dict["backgroundUrl"] as? String ?? ""
    }

    func toDict() -> [String: Any] {
        return [
            "username": username,
            "email": email,
            "avatarUrl": avatarUrl,
            "backgroundUrl": backgroundUrl
        ]
    }
}
