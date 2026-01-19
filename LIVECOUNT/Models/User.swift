//
//  User.swift
//  LIVECOUNT
//
//  Created by Roman M'BARALI on 08/01/2026.
//

import Foundation

struct User: Identifiable, Codable {
    let id: String
    let email: String?
    let role: UserRole
    let createdAt: Date
}