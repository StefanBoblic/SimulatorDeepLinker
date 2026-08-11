//
//  LaunchHistoryEntry.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 11.08.2026.
//

import Foundation

struct LaunchHistoryEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let linkTitle: String
    let urlString: String
    let targetName: String
    let platform: DevicePlatform
    let succeeded: Bool
    let message: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        linkTitle: String,
        urlString: String,
        targetName: String,
        platform: DevicePlatform,
        succeeded: Bool,
        message: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.linkTitle = linkTitle
        self.urlString = urlString
        self.targetName = targetName
        self.platform = platform
        self.succeeded = succeeded
        self.message = message
        self.createdAt = createdAt
    }
}
