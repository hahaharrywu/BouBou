//
//  UserProfile.swift
//  BouBou
//
//  Created by Hongrui Wu  on 6/8/25.
//


struct UserProfile {
    let userId: String
    let customUserName: String
    let email: String
    let avatarUrl: String
    let backgroundUrl: String

    init(documentID: String, dict: [String: Any]) {
        self.userId = documentID
        self.customUserName = dict["customUserName"] as? String ?? ""
        self.email = dict["email"] as? String ?? ""
        self.avatarUrl = dict["avatarUrl"] as? String ?? ""
        self.backgroundUrl = dict["backgroundUrl"] as? String ?? ""
    }

    func toDict() -> [String: Any] {
        return [
            "customUserName": customUserName,
            "email": email,
            "avatarUrl": avatarUrl,
            "backgroundUrl": backgroundUrl
        ]
    }
}
