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
            let key = NSRegularExpression.escapedPattern(for: variable.key)
            let pattern = "\\{\\{\\s*\(key)\\s*\\}\\}|\\$\\{\\s*\(key)\\s*\\}"
            return value.replacingOccurrences(
                of: pattern,
                with: NSRegularExpression.escapedTemplate(for: variable.value),
                options: .regularExpression
            )
        }
    }
}
