//
//  LinkEnvironment.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 11.08.2026.
//

import Foundation

struct LinkEnvironment: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var variables: [String: String]
    var isBuiltIn: Bool

    init(
        id: UUID = UUID(),
        name: String,
        variables: [String: String] = [:],
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.variables = variables
        self.isBuiltIn = isBuiltIn
    }

    static let none = LinkEnvironment(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        name: String(localized: "None")
    )

    static let development = LinkEnvironment(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Development",
        isBuiltIn: true
    )

    static let production = LinkEnvironment(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "Production",
        isBuiltIn: true
    )

    var displayName: String {
        switch id {
        case Self.development.id: String(localized: "Development")
        case Self.production.id: String(localized: "Production")
        default: name
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case variables
        case isBuiltIn
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        variables = try container.decodeIfPresent([String: String].self, forKey: .variables) ?? [:]
        isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
    }
}
