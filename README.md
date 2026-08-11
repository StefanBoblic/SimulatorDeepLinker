# SimulatorDeepLinker

<p align="center">
  <img src="docs/logo.png" alt="SimulatorDeepLinker icon" width="160">
</p>

A native macOS app for organizing and testing deep links across iOS and Android devices.

## Features

- Save, search, group, tag, favorite, import, export, and batch-open deep links
- Discover booted iOS Simulators, paired iPhones and iPads, and connected Android devices
- Open links through `simctl`, `devicectl`, or ADB over USB and Wi-Fi
- Define environments and substitute `{{KEY}}` or `${KEY}` variables in URLs
- Use the built-in Development and Production environments or create UAT, QA, Staging, and custom environments
- Generate a QR code for opening a link on any nearby device
- Review a local history of successful launches and errors
- Add a URL directly from the clipboard
- Use the interface in English or Russian
- Share the JSON storage file with Raycast or another local tool
- Keep everything local — no accounts, analytics, or tracking

## Install

With Homebrew:

```bash
brew tap StefanBoblic/tap
brew install --cask simulator-deep-linker
```

Or download the latest app from [GitHub Releases](https://github.com/StefanBoblic/SimulatorDeepLinker/releases/latest), unzip it, and move it to `/Applications`.

## Use

1. Start an iOS Simulator, connect an Android device, or pair an Apple device with Xcode.
2. Add a URL such as `myapp://product/123` or `https://example.com/product/123`.
3. Choose a discovered target and, when needed, enter the app bundle identifier or Android package.
4. Click **Open** or press `⌘↩`.

SimulatorDeepLinker uses Apple's and Android's developer tools:

```bash
xcrun simctl openurl <device> <url>
xcrun devicectl device process launch --device <device> <bundle-id> --payload-url <url>
adb -s <device> shell am start -a android.intent.action.VIEW -d <url>
```

Xcode is required for Apple targets. Android Platform Tools are required for Android targets.

## Environments and Wi-Fi devices

Development and Production are created automatically. Configure their variables in **Settings → Environments**, or add UAT, QA, Staging, and any other environment you need. Built-in environments cannot be deleted, but their variables remain fully editable.

Use variables such as `{{BASE_URL}}/product/${PRODUCT_ID}` in saved links. Environments are stored in `environments.json` next to `deeplinks.json`, so the app, CLI, and Raycast extension use the same values.

`BASE_URL` and `PRODUCT_ID` are examples, not built-in values. You choose each variable name and define its value in **Settings → Environments**, for example `BASE_URL=https://dev.example.com` for Development and `BASE_URL=https://example.com` for Production.

```json
[
  {
    "id": "00000000-0000-0000-0000-000000000001",
    "name": "Development",
    "variables": {
      "BASE_URL": "https://dev.example.com",
      "PRODUCT_ID": "42"
    },
    "isBuiltIn": true
  }
]
```

For wireless Android debugging, pair the device once with its address and pairing code, then connect to its ADB address from the target section.

## Groups, tags, and environment resolution

- **Group** is one optional broad category, such as `Authentication`, `Catalog`, or `Checkout`. Groups become sidebar filters.
- **Tags** are multiple comma-separated labels, such as `ios, smoke, regression`. Tags are searchable and are useful for platforms, test suites, and temporary labels.
- **Environment** supplies values for placeholders in a saved URL. Selecting an environment never modifies the saved template; it only changes the resolved preview, the URL sent by **Open**, and the generated QR code.

For example, save this template once:

```text
{{BASE_URL}}/product/${PRODUCT_ID}
```

With `BASE_URL=https://dev.example.com` and `PRODUCT_ID=42`, Development resolves it to:

```text
https://dev.example.com/product/42
```

Production can resolve the same saved template to `https://example.com/product/42`. Placeholders without configured values remain unchanged, so configure every required variable before opening the link. The same guide is available inside **Settings → Guide**.

## Shared storage

Open **Settings → Shared Storage** to choose an existing JSON file, create a shared copy, copy its path, or return to the default location. Changes made by external tools are reloaded automatically.

The file contains a JSON array. Dates use ISO 8601:

```json
[
  {
    "id": "8DB1E10D-20DB-4A4B-95B8-845156B4873A",
    "title": "Product details",
    "urlString": "myapp://product/123",
    "group": "Shop",
    "tags": ["product", "debug"],
    "isFavorite": true,
    "createdAt": "2026-08-11T09:00:00Z",
    "updatedAt": "2026-08-11T09:00:00Z"
  }
]
```

## CLI

Build the native command-line executable:

```bash
cd CLI
swift build -c release
```

Examples:

```bash
.build/release/simulator-deep-linker list
.build/release/simulator-deep-linker environments
.build/release/simulator-deep-linker resolve Product --environment Development
.build/release/simulator-deep-linker open Product --environment UAT
.build/release/simulator-deep-linker open Product --platform android --target emulator-5554
```

Use `--storage /path/to/deeplinks.json` or the `SIMULATOR_DEEP_LINKER_STORAGE` environment variable when the CLI cannot discover the app's custom storage automatically.

## Raycast extension

The extension in `RaycastExtension` provides fast search, environment selection, resolved URL copying, and one-action opening. It detects the active storage automatically and invokes `xcrun` or `adb` directly, so the CLI and manual file selection are not required.

```bash
./scripts/install_raycast_extension.sh
```

Open SimulatorDeepLinker once before using the extension. The app writes `integration.json` in its Application Support directory whenever the active storage changes. The extension falls back to the default storage and offers an optional override in Raycast preferences.

## Development

```bash
git clone https://github.com/StefanBoblic/SimulatorDeepLinker.git
cd SimulatorDeepLinker
open SimulatorDeepLinker.xcodeproj
```

Build and run the app from Xcode. The target intentionally does not use App Sandbox because sandboxed apps cannot execute `xcrun`.

The source follows MVVM: SwiftUI views bind to view models, view models coordinate protocol-based services, and stores own persisted application data. This keeps command execution, device discovery, and storage independently testable.

To package a release:

```bash
./scripts/package_release.sh 0.1.0
```

Saved links stay on your Mac under Application Support. See [LICENSE](LICENSE) for license information.
