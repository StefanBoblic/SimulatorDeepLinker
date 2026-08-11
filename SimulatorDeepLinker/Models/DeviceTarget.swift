//
//  DeviceTarget.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 11.08.2026.
//

import Foundation

enum DevicePlatform: String, Codable, CaseIterable, Sendable {
    case iOSSimulator
    case iOSDevice
    case android

    var title: String {
        switch self {
        case .iOSSimulator: String(localized: "iOS Simulator")
        case .iOSDevice: String(localized: "iPhone or iPad")
        case .android: String(localized: "Android")
        }
    }

    var systemImage: String {
        switch self {
        case .iOSSimulator: "iphone.gen3"
        case .iOSDevice: "iphone"
        case .android: "apps.iphone"
        }
    }
}

struct DeviceTarget: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let platform: DevicePlatform
    let identifier: String
    let detail: String

    static let bootedSimulator = DeviceTarget(
        id: "ios-simulator-booted",
        name: String(localized: "Booted iOS Simulator"),
        platform: .iOSSimulator,
        identifier: "booted",
        detail: String(localized: "Uses the currently booted simulator")
    )
}
