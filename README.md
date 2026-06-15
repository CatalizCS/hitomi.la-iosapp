# HitomiReader

A native SwiftUI iOS app for browsing and reading content from hitomi.la.

## Requirements

- macOS with Xcode 15+ installed
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- iOS 16.0+ device or simulator

## Build Locally

1. **Install XcodeGen** (if not already installed):
   ```bash
   brew install xcodegen
   ```

2. **Generate the Xcode project**:
   ```bash
   xcodegen generate
   ```

3. **Open in Xcode**:
   ```bash
   open HitomiReader.xcodeproj
   ```

4. **Build and run** on a simulator or device from Xcode.

> **Note:** The project is configured for unsigned builds by default. To run on a physical device through Xcode, update the `DEVELOPMENT_TEAM` and code signing settings in `project.yml` or in Xcode's Signing & Capabilities tab.

## Build with GitHub Actions

The project includes a GitHub Actions workflow that automatically builds an unsigned IPA:

1. Push your code to the `main` branch, or trigger the workflow manually from the **Actions** tab.
2. The workflow will:
   - Install XcodeGen
   - Generate the `.xcodeproj`
   - Build a Release archive
   - Package it into an unsigned `.ipa`
3. Download the IPA from the workflow's **Artifacts** section.

## Install the IPA

Since the IPA is unsigned, you'll need to sideload it using one of these tools:

| Tool | Notes |
|------|-------|
| [AltStore](https://altstore.io/) | Free, requires periodic refresh every 7 days |
| [Sideloadly](https://sideloadly.io/) | Free, supports Windows & macOS |
| [TrollStore](https://github.com/opa334/TrollStore) | Permanent install, requires compatible iOS version |

## Project Structure

```
├── project.yml                  # XcodeGen project specification
├── HitomiReader/
│   ├── Info.plist               # App configuration
│   ├── Assets.xcassets/         # Asset catalog (colors, icons)
│   ├── HitomiReaderApp.swift    # App entry point
│   ├── Models/                  # Data models
│   ├── Views/                   # SwiftUI views
│   ├── ViewModels/              # View models
│   └── Services/                # Networking & JS evaluation
├── .github/workflows/
│   └── build.yml                # GitHub Actions CI/CD
└── .gitignore
```

## License

This project is for personal/educational use only.
