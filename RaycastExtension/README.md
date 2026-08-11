# SimulatorDeepLinker for Raycast

Search saved deep links, switch environments, copy resolved URLs, and open links on the target configured in Raycast.

## Setup

1. Build the CLI with `cd CLI && swift build -c release`.
2. In `RaycastExtension`, run `npm install` and `npm run dev`.
3. Select your `deeplinks.json` and the built `simulator-deep-linker` executable when Raycast asks for preferences.
4. Set the default platform and target. Use `booted` for the active iOS Simulator.

The extension reads `environments.json` next to `deeplinks.json`, so Development, Production, and custom environments stay synchronized with the macOS app.

Before publishing or linting for the Raycast Store, replace `YOUR_RAYCAST_USERNAME` in `package.json` with your Raycast handle.
