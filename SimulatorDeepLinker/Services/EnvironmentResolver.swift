//
//  EnvironmentResolver.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 11.08.2026.
//

import Foundation

enum EnvironmentResolver {
    static func resolve(_ source: String, variables: [String: String]) -> String {
        variables.reduce(source) { value, variable in
            value
                .replacingOccurrences(of: "{{\(variable.key)}}", with: variable.value)
                .replacingOccurrences(of: "${\(variable.key)}", with: variable.value)
        }
    }
}
