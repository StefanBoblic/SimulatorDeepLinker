//
//  StatusMessage.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 22.05.2026.
//

struct StatusMessage: Equatable {
    enum Kind {
        case success
        case error

        var systemImageName: String {
            switch self {
            case .success:
                return "checkmark.circle.fill"
            case .error:
                return "exclamationmark.triangle.fill"
            }
        }
    }

    let kind: Kind
    let text: String
}
