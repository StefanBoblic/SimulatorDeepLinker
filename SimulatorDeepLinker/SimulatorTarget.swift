//
//  DeepLinkItem.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 22.05.2026.
//

import Foundation

enum SimulatorTarget: String, CaseIterable, Identifiable {
    case booted = "booted"
    case custom = "custom"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .booted:
            return String(localized: "Booted simulator")
        case .custom:
            return String(localized: "Custom UDID")
        }
    }
}
