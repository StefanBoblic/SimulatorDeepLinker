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

    init(id: UUID = UUID(), name: String, variables: [String: String] = [:]) {
        self.id = id
        self.name = name
        self.variables = variables
    }

    static let none = LinkEnvironment(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        name: String(localized: "None")
    )
}
