//
//  DeepLinkItem.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 22.05.2026.
//


import Foundation

struct DeepLinkItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var urlString: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        urlString: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}