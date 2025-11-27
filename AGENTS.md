# Repository Guidelines

## Project Structure & Module Organization
- `Sources/App`: entry point (ZestApp, AppDelegate), menu bar wiring, permissions handling.
- `Sources/Core`: shared models, constants, and services (clipboard, storage, hotkeys, logging, launch).
- `Sources/Features`: SwiftUI/AppKit features; `History` holds list/window views, `Preferences` contains settings UI.
- `Tests/ZestTests`: XCTest cases; mirror new modules here.
- Packaging artifacts live in `Zest_App/` (assembled `.app`) and `Zest_Installer.dmg` after release builds. Scripts `package.sh` and `create_dmg.sh` handle bundling.

## Build, Test, and Development Commands
```bash
swift build -c debug      # fastest local builds
swift run                 # run Zest from the package target
swift test                # execute XCTest suite
swift build -c release    # optimized build used by packaging
./package.sh              # build universal binary + bundle into Zest_App/Zest.app
./create_dmg.sh           # produce Zest_Installer.dmg from Zest_App output
open Package.swift        # open in Xcode (macOS 14 / Xcode 15)
```

## Coding Style & Naming Conventions
- Follow Swift API Design Guidelines; camelCase for members, UpperCamelCase for types; avoid force unwraps.
- Keep UI work on the main actor (`@MainActor` on UI-facing services/views).
- Centralize constants in `Sources/Core/Constants.swift`; reuse services instead of scattering logic.
- Prefer small SwiftUI views backed by lightweight view models; keep side effects inside services.
- Logging: lightweight `print` with clear prefixes/emojis is used in this codebase—stay consistent for quick Console filtering.

## Testing Guidelines
- Use XCTest; place files under `Tests/ZestTests` mirroring source folders.
- Name tests with intent (e.g., `testHistoryDeduplicatesNewPaste`) and cover new branches/edge cases.
- Run `swift test` before opening a PR; include simple integration-style tests for services (clipboard, hotkeys, storage) where feasible.

## Commit & Pull Request Guidelines
- Commit messages follow emoji + type prefixes already in history (e.g., `✨ feat: add history search`, `🐛 fix: hotkey registration`).
- Keep PRs focused; include a short summary, linked issue/ticket, and UI screenshots/GIFs for visible changes.
- List build/test steps you ran (`swift test`, `package.sh` if packaging changed) and any known limitations.
- For feature work, mention permission impacts (e.g., Accessibility) and data migration considerations to aid reviewers.

## Packaging & Release Tips
- Run `swift build -c release` first; `package.sh` assembles a universal binary, generates icons, writes `Info.plist`, and performs ad-hoc signing.
- After verifying the app bundle in `Zest_App/`, execute `create_dmg.sh` to generate the distributable DMG.
- Clean up or regenerate `Zest_App/` outputs when bumping versions to avoid stale binaries.
