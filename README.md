# SimulatorDeepLinker

<img width="906" height="621" alt="image" src="https://github.com/user-attachments/assets/986b5b87-b059-4b04-8e8c-634eebd65769" />

<p align="center">
  <img src="docs/logo.png" alt="SimulatorDeepLinker logo" width="180">
</p>

<p align="center">
  A small macOS utility for saving deep links and opening them in the iOS Simulator.
</p>

<p align="center">
  <a href="https://github.com/StefanBoblic/SimulatorDeepLinker/releases">Releases</a>
  ·
  <a href="#installation">Installation</a>
  ·
  <a href="#usage">Usage</a>
</p>

---

## Overview

**SimulatorDeepLinker** is a lightweight macOS app for iOS developers who often need to test deep links, universal links, and app-specific URL schemes in the iOS Simulator.

Instead of keeping links in notes, chats, or browser tabs, you can save them in one place and open any link in the currently running simulator with one click.

Under the hood, the app uses:

```bash
xcrun simctl openurl booted "https://example.com/path"
```

---

## Features

* Save frequently used deep links
* Open links in the currently booted iOS Simulator
* Support for universal links, regular web links, and custom URL schemes
* Search saved links
* Edit and delete saved links
* Local file-based storage
* Native macOS SwiftUI interface
* No backend, no tracking, no accounts

---

## Installation

### Homebrew

SimulatorDeepLinker is available via Homebrew Cask from a custom tap:

```bash
brew tap StefanBoblic/tap
brew install --cask simulator-deep-linker
```

Then launch it:

```bash
open -a SimulatorDeepLinker
```

### Update

```bash
brew update
brew upgrade --cask simulator-deep-linker
```

### Uninstall

```bash
brew uninstall --cask simulator-deep-linker
```

To remove the app and local saved data:

```bash
brew uninstall --cask --zap simulator-deep-linker
```

---

## Manual Installation

You can also download the latest `.zip` from the [Releases](https://github.com/StefanBoblic/SimulatorDeepLinker/releases) page.

1. Download `SimulatorDeepLinker-<version>.zip`
2. Unzip it
3. Move `SimulatorDeepLinker.app` to `/Applications`
4. Launch the app

If macOS blocks the app on first launch, open it via:

```bash
open /Applications/SimulatorDeepLinker.app
```

or allow it in:

```text
System Settings → Privacy & Security
```

---

## Usage

1. Start an iOS Simulator.
2. Open SimulatorDeepLinker.
3. Add a link, for example:

```text
https://example.com/product/123
```

or:

```text
myapp://product/123
```

4. Click **Open**.

The app will send the link to the currently booted simulator.

---

## Link Types

### Universal Links

```text
https://example.com/some/path
```

Universal links are opened through the simulator environment and can be handled by your installed app if Associated Domains are configured correctly.

### Custom URL Schemes

```text
myapp://screen/details?id=123
```

Custom schemes are passed to the simulator and opened by an app that has registered the scheme.

### Web Links

```text
https://apple.com
```

Regular web links will open in Safari inside the iOS Simulator.

---

## Local Storage

Saved links are stored locally on your Mac in Application Support as a JSON file.

Typical location:

```text
~/Library/Application Support/<bundle-id>/deeplinks.json
```

The app does not sync or upload your links anywhere.

---

## Requirements

* macOS
* Xcode installed
* iOS Simulator available
* At least one simulator booted before opening a link

You can check that the simulator command works manually:

```bash
xcrun simctl openurl booted "https://example.com"
```

---

## Development

Clone the repository:

```bash
git clone https://github.com/StefanBoblic/SimulatorDeepLinker.git
cd SimulatorDeepLinker
open SimulatorDeepLinker.xcodeproj
```

Build and run the app from Xcode.

### Important

The app must not run inside App Sandbox, because `xcrun` cannot be used from a sandboxed macOS app.

If you see this error:

```text
xcrun: error: cannot be used within an App Sandbox.
```

Disable App Sandbox in Xcode:

```text
Target → Signing & Capabilities → App Sandbox
```

---

## Release Packaging

To build a release archive and zip the app:

```bash
./scripts/package_release.sh 0.1.0
```

The script creates:

```text
build/SimulatorDeepLinker-0.1.0.zip
```

and prints the `sha256` needed for the Homebrew Cask.

---

## Homebrew Tap

The Homebrew Cask is located in:

```text
https://github.com/StefanBoblic/homebrew-tap
```

Cask path:

```text
Casks/simulator-deep-linker.rb
```

Install command:

```bash
brew tap StefanBoblic/tap
brew install --cask simulator-deep-linker
```

---

## Troubleshooting

### `No booted devices`

Start an iOS Simulator first, then try again.

You can open Simulator manually from Xcode:

```text
Xcode → Open Developer Tool → Simulator
```

or from terminal:

```bash
open -a Simulator
```

### `xcrun: error: cannot be used within an App Sandbox`

Disable App Sandbox in the app target.

This app is intended as a local developer tool and needs to execute `xcrun simctl`.

### Link opens Safari instead of the app

For universal links, make sure that:

* the app is installed in the simulator
* Associated Domains are configured
* the domain hosts the correct `apple-app-site-association` file
* the app build supports the universal link path

For custom URL schemes, make sure the scheme is registered in the app's `Info.plist`.

---

## Privacy

SimulatorDeepLinker stores links only locally on your Mac.

It does not collect analytics, send network requests, or use any external backend.

---

## License

MIT License
