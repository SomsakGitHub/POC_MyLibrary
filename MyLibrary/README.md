# MyLibrary

MyLibrary is an iOS SDK distributed to consuming apps as binary Swift Package Manager products. The source package in this repository is for the SDK build and release pipeline; the package consumers depend on is a binary-only manifest hosted on a dedicated `release` branch whose tags point at XCFramework archives uploaded to GitHub Releases.

## Products

| SPM product | Swift module imported by the app | Purpose |
| --- | --- | --- |
| `MyLibrarySDKCore` | `MyLibrarySDKCoreBinary` | SDK configuration and shared types |
| `MyLibrarySDKFeature` | `MyLibrarySDKFeatureBinary` | UIKit flow; links the Core binary |

The binary module names end in `Binary` because the public API types already use the product names. This avoids Swift module/type name collisions while keeping the product names shown in Xcode unchanged.

## Build and publish a release

The build host needs macOS, Xcode with the iOS and iOS Simulator SDKs, Swift 5.9 or later, Python 3, and an authenticated [GitHub CLI](https://cli.github.com) (`gh auth login`). The publishing identity needs write access to the repository and permission to create releases.

Release settings are read from `.github.env` and can be overridden by environment variables:

- `GITHUB_REPO`: repository in `owner/repo` form. Defaults to the `origin` remote.
- `RELEASE_BRANCH`: branch that holds the binary manifest (default `release`).
- `TAG_PREFIX`: version tag prefix (default `v`).

For a local release, copy `.github.env.example` to `.github.env`, fill in the values, and restrict its permissions:

```sh
cp .github.env.example .github.env
chmod 600 .github.env
```

Build XCFrameworks and checksums locally:

```sh
./scripts/build-binary-release.sh 1.0.0
```

Publish the binary archives to GitHub Releases and the binary-only package to the `release` branch:

```sh
./scripts/publish-binary-release.sh 1.0.0
```

The script renders `Distribution/Package.swift.template` with the release asset URLs and checksums, commits that manifest to the `release` branch, tags the commit, pushes both, and uploads the ZIPs to a GitHub Release. The release is versioned and immutable: publish a new version for each change and never republish an existing tag. The XCFrameworks cover iOS devices (`arm64`) and simulators (`arm64` and `x86_64`) with iOS 15 as the deployment target. `Distribution/output/` is generated and ignored by Git.

## Add the binary package to an app

Add the package using the repository URL and a semantic version. The tag resolved by SwiftPM points at the binary-only manifest on the `release` branch.

In a `Package.swift` manifest:

```swift
.package(url: "https://github.com/<OWNER>/<REPO>.git", from: "1.0.0")

.product(name: "MyLibrarySDKCore", package: "POC_MyLibrary"),
.product(name: "MyLibrarySDKFeature", package: "POC_MyLibrary"),
```

In Xcode, use **File > Add Package Dependencies**, paste the repository URL, choose the version, and select the `MyLibrarySDKCore` and/or `MyLibrarySDKFeature` products.

For a private repository, SwiftPM must authenticate to clone the repo and download the release assets. Provide a token through `~/.netrc` on the consumer machine:

```text
machine github.com login <GITHUB_USER> password <GITHUB_TOKEN>
```

`<GITHUB_TOKEN>` is a personal access token with read access to the repository (classic tokens need the `repo` scope; fine-grained tokens need repository contents read). Protect the file with `chmod 600 ~/.netrc`. Release asset downloads are served from `github.com`, so the same `netrc` entry covers them.

The app imports the binary modules while retaining the current SDK API:

```swift
import UIKit
import MyLibrarySDKCoreBinary
import MyLibrarySDKFeatureBinary

@MainActor
func configureMyLibrary() {
    MyLibrarySDKCore.initialize(
        app: MyLibraryAppConfig(
            hostAppName: "MyApp",
            environment: .prod,
            debugMode: false
        )
    )
}

@MainActor
func openMyLibrary(from viewController: UIViewController) {
    MyLibrarySDKFeature.startFlow(
        data: MyLibraryFlowData(
            accountNo: "123456",
            appCode: "MYAPP",
            productCode: "SAVINGS"
        ),
        from: viewController
    )
}
```

`startFlow` runs on the main actor and requires `MyLibrarySDKCore.initialize(app:)` first. Passing the presenting view controller is recommended.

## Source development

The root `Package.swift` builds the source targets for SDK development. Do not publish that source package to consumers. The release script renders `Distribution/Package.swift.template` with the versioned release asset URLs and checksums, then commits that manifest to the `release` branch and tags it. The public binaries are downloaded and checksum-verified by SwiftPM.

## License

A license has not been selected for this package yet. Add the approved license file before distributing it to third parties.
