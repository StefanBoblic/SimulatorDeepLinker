//
//  DeviceDiscoveryService.swift
//  SimulatorDeepLinker
//
//  Created by Stefan Boblic on 11.08.2026.
//

import Foundation

protocol DeviceDiscovering: Sendable {
    func discover() async -> [DeviceTarget]
}

struct DeviceDiscoveryService: DeviceDiscovering {
    private let runner: any CommandRunning
    private let executables: any ExecutableLocating

    init(
        runner: any CommandRunning = ProcessCommandRunner(),
        executables: any ExecutableLocating = ExecutableLocator()
    ) {
        self.runner = runner
        self.executables = executables
    }

    func discover() async -> [DeviceTarget] {
        async let simulators = discoverIOSSimulators()
        async let physicalDevices = discoverIOSDevices()
        async let androidDevices = discoverAndroidDevices()

        let discovered = await simulators + physicalDevices + androidDevices
        return [DeviceTarget.bootedSimulator] + discovered.sorted {
            if $0.platform != $1.platform {
                return $0.platform.rawValue < $1.platform.rawValue
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func discoverIOSSimulators() async -> [DeviceTarget] {
        guard let xcrun = executables.locate("xcrun"),
              let result = try? await runner.run(
                executableURL: xcrun,
                arguments: ["simctl", "list", "devices", "booted", "--json"]
              ),
              result.statusCode == 0,
              let data = result.stdout.data(using: .utf8),
              let payload = try? JSONDecoder().decode(SimctlDevicePayload.self, from: data) else {
            return []
        }

        return payload.devices.flatMap { runtime, devices in
            devices.compactMap { device -> DeviceTarget? in
                guard device.state.caseInsensitiveCompare("Booted") == .orderedSame,
                      device.isAvailable != false,
                      device.udid.isEmpty == false else { return nil }

                return DeviceTarget(
                    id: "ios-simulator-\(device.udid)",
                    name: device.name,
                    platform: .iOSSimulator,
                    identifier: device.udid,
                    detail: Self.runtimeName(from: runtime)
                )
            }
        }
    }

    private func discoverAndroidDevices() async -> [DeviceTarget] {
        guard let adb = executables.locate("adb"),
              let result = try? await runner.run(executableURL: adb, arguments: ["devices", "-l"]),
              result.statusCode == 0 else {
            return []
        }

        return Self.parseADBDevices(result.stdout)
    }

    private func discoverIOSDevices() async -> [DeviceTarget] {
        guard let xcrun = executables.locate("xcrun") else { return [] }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SimulatorDeepLinker-devices-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        guard let result = try? await runner.run(
            executableURL: xcrun,
            arguments: ["devicectl", "list", "devices", "--json-output", outputURL.path]
        ), result.statusCode == 0,
              let data = try? Data(contentsOf: outputURL) else {
            return []
        }

        return Self.parseCoreDevices(data)
    }

    static func parseADBDevices(_ output: String) -> [DeviceTarget] {
        let lines: [Substring] = output.split(whereSeparator: { $0.isNewline })
        return lines.compactMap { line -> DeviceTarget? in
                let fields = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
                guard fields.count >= 2,
                      fields[0] != "List",
                      fields[1] == "device" else { return nil }

                let identifier = fields[0]
                let propertyPairs: [(String, String)] = fields.dropFirst(2).compactMap { field in
                    let parts = field.split(separator: ":", maxSplits: 1).map(String.init)
                    guard parts.count == 2 else { return nil }
                    return (parts[0], parts[1])
                }
                let properties = Dictionary(uniqueKeysWithValues: propertyPairs)
                let model = properties["model"]?.replacingOccurrences(of: "_", with: " ")
                let detail: String
                if identifier.hasPrefix("emulator-") {
                    detail = String(localized: "Android Emulator")
                } else if identifier.contains(":") {
                    detail = String(localized: "Wireless ADB")
                } else {
                    detail = String(localized: "USB")
                }

                return DeviceTarget(
                    id: "android-\(identifier)",
                    name: model ?? identifier,
                    platform: .android,
                    identifier: identifier,
                    detail: detail
                )
        }
    }

    static func parseCoreDevices(_ data: Data) -> [DeviceTarget] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = root["result"] as? [String: Any],
              let devices = result["devices"] as? [[String: Any]] else {
            return []
        }

        return devices.compactMap { device -> DeviceTarget? in
            let hardware = device["hardwareProperties"] as? [String: Any] ?? [:]
            let properties = device["deviceProperties"] as? [String: Any] ?? [:]
            let connection = device["connectionProperties"] as? [String: Any] ?? [:]
            let platform = (hardware["platform"] as? String) ?? ""
            let deviceType = (hardware["deviceType"] as? String) ?? ""

            guard platform.localizedCaseInsensitiveContains("iOS")
                    || deviceType.localizedCaseInsensitiveContains("iPhone")
                    || deviceType.localizedCaseInsensitiveContains("iPad") else {
                return nil
            }

            guard let identifier = (device["identifier"] as? String)
                    ?? (hardware["udid"] as? String),
                  identifier.isEmpty == false else { return nil }

            let name = (properties["name"] as? String)
                ?? (hardware["marketingName"] as? String)
                ?? identifier
            let osVersion = properties["osVersionNumber"] as? String
            let transport = connection["transportType"] as? String
            let detail = [osVersion, transport]
                .compactMap { $0 }
                .filter { $0.isEmpty == false }
                .joined(separator: " • ")

            return DeviceTarget(
                id: "ios-device-\(identifier)",
                name: name,
                platform: .iOSDevice,
                identifier: identifier,
                detail: detail.isEmpty ? String(localized: "Paired device") : detail
            )
        }
    }

    private static func runtimeName(from identifier: String) -> String {
        identifier
            .replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "")
            .replacingOccurrences(of: "-", with: " ")
    }
}

private struct SimctlDevicePayload: Decodable {
    let devices: [String: [SimctlDevice]]
}

private struct SimctlDevice: Decodable {
    let name: String
    let udid: String
    let state: String
    let isAvailable: Bool?
}
