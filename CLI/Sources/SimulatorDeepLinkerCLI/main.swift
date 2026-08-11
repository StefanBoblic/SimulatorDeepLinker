//
//  main.swift
//  SimulatorDeepLinkerCLI
//
//  Created by Stefan Boblic on 11.08.2026.
//

import Foundation
import Darwin

struct DeepLink: Codable {
    let id: UUID
    let title: String
    let urlString: String
    let group: String?
    let tags: [String]?
    let isFavorite: Bool?
}

struct LinkEnvironment: Codable {
    let id: UUID
    let name: String
    let variables: [String: String]
    let isBuiltIn: Bool?
}

enum Platform: String {
    case ios
    case iOSDevice = "ios-device"
    case android
}

struct Options {
    var storagePath: String?
    var environmentName: String?
    var target = "booted"
    var platform: Platform = .ios
    var bundleIdentifier = ""
    var androidPackage = ""
    var json = false
    var positional: [String] = []
}

enum CLIError: LocalizedError {
    case usage(String)
    case fileNotFound(String)
    case linkNotFound(String)
    case environmentNotFound(String)
    case invalidURL(String)
    case executableNotFound(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case let .usage(message), let .fileNotFound(message), let .linkNotFound(message),
             let .environmentNotFound(message), let .invalidURL(message),
             let .executableNotFound(message), let .commandFailed(message):
            message
        }
    }
}

@main
struct SimulatorDeepLinkerCLI {
    static func main() {
        do {
            try run(arguments: Array(CommandLine.arguments.dropFirst()))
        } catch {
            FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
            exit(EXIT_FAILURE)
        }
    }

    private static func run(arguments: [String]) throws {
        guard let command = arguments.first else {
            printHelp()
            return
        }
        let options = try parse(Array(arguments.dropFirst()))
        let storageURL = try storageURL(override: options.storagePath)
        let environmentURL = storageURL.deletingLastPathComponent().appendingPathComponent("environments.json")

        switch command {
        case "help", "--help", "-h":
            printHelp()
        case "paths":
            if options.json {
                try printJSON(["storage": storageURL.path, "environments": environmentURL.path])
            } else {
                print("Storage: \(storageURL.path)")
                print("Environments: \(environmentURL.path)")
            }
        case "list":
            try list(storageURL: storageURL, options: options)
        case "environments":
            try listEnvironments(environmentURL: environmentURL, options: options)
        case "resolve":
            let resolved = try resolvedURL(
                query: try requiredQuery(options),
                storageURL: storageURL,
                environmentURL: environmentURL,
                environmentName: options.environmentName
            )
            print(resolved)
        case "open":
            let resolved = try resolvedURL(
                query: try requiredQuery(options),
                storageURL: storageURL,
                environmentURL: environmentURL,
                environmentName: options.environmentName
            )
            try open(resolved, options: options)
            print("Opened: \(resolved)")
        default:
            throw CLIError.usage("Unknown command '\(command)'. Run simulator-deep-linker help.")
        }
    }

    private static func parse(_ arguments: [String]) throws -> Options {
        var options = Options()
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--storage":
                options.storagePath = try value(after: argument, at: &index, in: arguments)
            case "--environment", "-e":
                options.environmentName = try value(after: argument, at: &index, in: arguments)
            case "--target", "-t":
                options.target = try value(after: argument, at: &index, in: arguments)
            case "--platform", "-p":
                let value = try value(after: argument, at: &index, in: arguments)
                guard let platform = Platform(rawValue: value) else {
                    throw CLIError.usage("Platform must be ios, ios-device, or android.")
                }
                options.platform = platform
            case "--bundle-id":
                options.bundleIdentifier = try value(after: argument, at: &index, in: arguments)
            case "--package":
                options.androidPackage = try value(after: argument, at: &index, in: arguments)
            case "--json":
                options.json = true
            default:
                if argument.hasPrefix("-") {
                    throw CLIError.usage("Unknown option '\(argument)'.")
                }
                options.positional.append(argument)
            }
            index += 1
        }
        return options
    }

    private static func value(after option: String, at index: inout Int, in arguments: [String]) throws -> String {
        index += 1
        guard index < arguments.count else {
            throw CLIError.usage("Missing value after \(option).")
        }
        return arguments[index]
    }

    private static func storageURL(override: String?) throws -> URL {
        if let override, override.isEmpty == false {
            return URL(fileURLWithPath: NSString(string: override).expandingTildeInPath).standardizedFileURL
        }
        if let environmentPath = ProcessInfo.processInfo.environment["SIMULATOR_DEEP_LINKER_STORAGE"],
           environmentPath.isEmpty == false {
            return URL(fileURLWithPath: NSString(string: environmentPath).expandingTildeInPath).standardizedFileURL
        }
        if let appDefaults = UserDefaults(suiteName: "com.stefan.SimulatorDeepLinker"),
           let customPath = appDefaults.string(forKey: "customDeepLinkStoragePath"),
           customPath.isEmpty == false {
            return URL(fileURLWithPath: customPath).standardizedFileURL
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.stefan.SimulatorDeepLinker/deeplinks.json")
    }

    private static func loadLinks(from fileURL: URL) throws -> [DeepLink] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw CLIError.fileNotFound("Storage file not found at \(fileURL.path).")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([DeepLink].self, from: Data(contentsOf: fileURL))
    }

    private static func loadEnvironments(from fileURL: URL) throws -> [LinkEnvironment] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [.development, .production]
        }
        return try JSONDecoder().decode([LinkEnvironment].self, from: Data(contentsOf: fileURL))
    }

    private static func list(storageURL: URL, options: Options) throws {
        let links = try loadLinks(from: storageURL)
        if options.json {
            try printJSON(links)
            return
        }
        for link in links {
            let metadata = [link.group ?? "", (link.tags ?? []).joined(separator: ",")]
                .filter { $0.isEmpty == false }
                .joined(separator: " • ")
            print("\(link.id.uuidString)\t\(link.title)\t\(link.urlString)\(metadata.isEmpty ? "" : "\t\(metadata)")")
        }
    }

    private static func listEnvironments(environmentURL: URL, options: Options) throws {
        let environments = try loadEnvironments(from: environmentURL)
        if options.json {
            try printJSON(environments)
            return
        }
        for environment in environments {
            let variables = environment.variables.keys.sorted().joined(separator: ", ")
            print("\(environment.name)\(variables.isEmpty ? "" : "\t\(variables)")")
        }
    }

    private static func resolvedURL(
        query: String,
        storageURL: URL,
        environmentURL: URL,
        environmentName: String?
    ) throws -> String {
        let links = try loadLinks(from: storageURL)
        let source: String
        if let id = UUID(uuidString: query), let link = links.first(where: { $0.id == id }) {
            source = link.urlString
        } else if let link = links.first(where: { $0.title.caseInsensitiveCompare(query) == .orderedSame }) {
            source = link.urlString
        } else if URL(string: query)?.scheme != nil {
            source = query
        } else {
            throw CLIError.linkNotFound("No saved link named '\(query)'.")
        }

        guard let environmentName, environmentName.isEmpty == false else { return source }
        let environments = try loadEnvironments(from: environmentURL)
        guard let environment = environments.first(where: {
            $0.name.caseInsensitiveCompare(environmentName) == .orderedSame
        }) else {
            throw CLIError.environmentNotFound("Environment '\(environmentName)' was not found.")
        }
        return environment.variables.reduce(source) { value, variable in
            value
                .replacingOccurrences(of: "{{\(variable.key)}}", with: variable.value)
                .replacingOccurrences(of: "${\(variable.key)}", with: variable.value)
        }
    }

    private static func open(_ urlString: String, options: Options) throws {
        guard let url = URL(string: urlString), url.scheme != nil else {
            throw CLIError.invalidURL("Invalid URL '\(urlString)'.")
        }
        switch options.platform {
        case .ios:
            try run(executable: "/usr/bin/xcrun", arguments: ["simctl", "openurl", options.target, url.absoluteString])
        case .iOSDevice:
            guard options.bundleIdentifier.isEmpty == false else {
                throw CLIError.usage("--bundle-id is required for ios-device.")
            }
            try run(
                executable: "/usr/bin/xcrun",
                arguments: [
                    "devicectl", "device", "process", "launch", "--device", options.target,
                    options.bundleIdentifier, "--payload-url", url.absoluteString
                ]
            )
        case .android:
            guard let adb = locateADB() else {
                throw CLIError.executableNotFound("adb was not found. Install Android Platform Tools or set ANDROID_HOME.")
            }
            var arguments = [
                "-s", options.target, "shell", "am", "start", "-W",
                "-a", "android.intent.action.VIEW", "-d", url.absoluteString
            ]
            if options.androidPackage.isEmpty == false { arguments.append(options.androidPackage) }
            try run(executable: adb, arguments: arguments)
        }
    }

    private static func run(executable: String, arguments: [String]) throws {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = errors.fileHandleForReading.readDataToEndOfFile()
            let fallback = output.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data.isEmpty ? fallback : data, encoding: .utf8) ?? "Command failed."
            throw CLIError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private static func locateADB() -> String? {
        var candidates: [String] = []
        if let sdk = ProcessInfo.processInfo.environment["ANDROID_HOME"]
            ?? ProcessInfo.processInfo.environment["ANDROID_SDK_ROOT"] {
            candidates.append(URL(fileURLWithPath: sdk).appendingPathComponent("platform-tools/adb").path)
        }
        candidates.append(FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Android/sdk/platform-tools/adb").path)
        for directory in (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":") {
            candidates.append(URL(fileURLWithPath: String(directory)).appendingPathComponent("adb").path)
        }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func requiredQuery(_ options: Options) throws -> String {
        guard options.positional.isEmpty == false else {
            throw CLIError.usage("Provide a saved link name, UUID, or URL.")
        }
        return options.positional.joined(separator: " ")
    }

    private static func printJSON<T: Encodable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        print(String(decoding: try encoder.encode(value), as: UTF8.self))
    }

    private static func printHelp() {
        print("""
        SimulatorDeepLinker CLI

        Usage:
          simulator-deep-linker paths [--json]
          simulator-deep-linker list [--storage <path>] [--json]
          simulator-deep-linker environments [--storage <path>] [--json]
          simulator-deep-linker resolve <name|uuid|url> [--environment <name>]
          simulator-deep-linker open <name|uuid|url> [options]

        Open options:
          --environment, -e <name>       Resolve environment variables
          --platform, -p <platform>      ios, ios-device, or android
          --target, -t <identifier>      booted, simulator UDID, device ID, or ADB serial
          --bundle-id <identifier>       Required for a physical Apple device
          --package <package>            Optional Android package
          --storage <path>               Override deeplinks.json

        SIMULATOR_DEEP_LINKER_STORAGE can also provide the storage path.
        """)
    }
}

private extension LinkEnvironment {
    static let development = LinkEnvironment(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Development",
        variables: [:],
        isBuiltIn: true
    )

    static let production = LinkEnvironment(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "Production",
        variables: [:],
        isBuiltIn: true
    )
}
