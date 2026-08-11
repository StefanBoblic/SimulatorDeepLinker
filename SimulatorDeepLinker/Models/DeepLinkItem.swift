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
    var group: String
    var tags: [String]
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        urlString: String,
        group: String = "",
        tags: [String] = [],
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.group = group
        self.tags = tags
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case urlString
        case group
        case tags
        case isFavorite
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        urlString = try container.decode(String.self, forKey: .urlString)
        group = try container.decodeIfPresent(String.self, forKey: .group) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}
