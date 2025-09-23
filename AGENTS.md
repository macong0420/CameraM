# Repository Guidelines

## Project Structure & Module Organization
Core app code lives under `CameraM/`. `AppDelegate.m`, `SceneDelegate.m`, and `main.m` wire application lifecycle events. Feature logic is split between `Controllers/` for orchestration, `Managers/` for system services (camera session, permissions), and `Views/` for reusable UI such as `CameraControlsView`. Assets reside in `Assets.xcassets`, while base storyboards and nibs sit in `Base.lproj`. Unit specs live in `CameraMTests/`; UI automation belongs in `CameraMUITests/`.

## Build, Test, and Development Commands
Prefer Xcode 15+ for day-to-day work. Run `xcodebuild -project CameraM.xcodeproj -scheme CameraM -sdk iphonesimulator build` to compile for the simulator. Execute both test targets with `xcodebuild test -project CameraM.xcodeproj -scheme CameraM -destination 'platform=iOS Simulator,name=iPhone 15'`. After a successful build, launch in the active simulator via `xcrun simctl launch booted com.example.CameraM` (update to the actual bundle identifier from `Info.plist`).

## Coding Style & Naming Conventions
Objective-C classes ship as `.h/.m` pairs with 4-space indentation. Organize methods using `#pragma mark` blocks and prefer explicit `nil` checks. Follow existing naming: `Camera*Controller` for presentation logic, `Camera*Manager` for services, and `*View` for UI components. Adopt UpperCamelCase for types, lowerCamelCase for methods and ivars, and prefix new shared utilities with `CM`. Assets and localized files should use descriptive, English identifiers that mirror visible UI strings.

## Testing Guidelines
Tests rely on XCTest. Place functional cases under `CameraMTests/` and name methods `test<Behavior>`. UI tests belong in `CameraMUITests/`, must launch `XCUIApplication` before assertions, and should document required permissions in comments. When touching capture performance, wrap measurements in `measureBlock:`. Keep simulator-based runs under two minutes; if longer, note the bottleneck in the PR description.

## Commit & Pull Request Guidelines
History favors emoji-prefixed, Mandarin subject lines (e.g., `🔧 修复横屏预览布局`). Keep each commit focused on a single fix or feature. Pull requests should link tracking issues, call out affected controllers/managers/views, and attach before/after screenshots for UI tweaks. Mention the simulator or device used for verification so reviewers can replicate results quickly.
