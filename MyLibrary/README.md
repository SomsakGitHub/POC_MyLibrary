# MyLibrary

MyLibrary is an iOS SDK distributed as a Swift Package. It currently provides two products:

- `MyLibrarySDKCore`: SDK configuration and shared types.
- `MyLibrarySDKFeature`: the UIKit flow. It depends on `MyLibrarySDKCore`.

## Requirements

- iOS 15.0 or later
- Swift Package Manager
- Xcode with Swift 5.9 or later

## Add the package

In Xcode, choose **File > Add Package Dependencies…**, enter this repository's Git URL, and select a released version. Add both `MyLibrarySDKCore` and `MyLibrarySDKFeature` to the app target.

Alternatively, declare the package in `Package.swift`:

```swift
.package(url: "https://github.com/<owner>/MyLibrary.git", from: "1.0.0")
```

Then add the products to the app target:

```swift
.product(name: "MyLibrarySDKCore", package: "MyLibrary"),
.product(name: "MyLibrarySDKFeature", package: "MyLibrary"),
```

Replace `<owner>` with the Git hosting account or organization that owns this repository.

## Configure and start the flow

Initialize the core once during app startup, then start the feature from a view controller:

```swift
import UIKit
import MyLibrarySDKCore
import MyLibrarySDKFeature

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
        from: viewController,
        onClose: { result in
            print("MyLibrary closed: \(result ?? "no result")")
        }
    )
}
```

`startFlow` must run on the main actor and requires `MyLibrarySDKCore.initialize(app:)` to have been called first. If `from` is omitted, the SDK attempts to find the topmost view controller in the key window. Supplying the presenting view controller is recommended when the host app controls its navigation.

## Products and targets

| Product | Use |
| --- | --- |
| `MyLibrarySDKCore` | Configure the SDK and access `MyLibraryAppConfig` / `MyLibraryEnvironment`. |
| `MyLibrarySDKFeature` | Present the UIKit flow; this product depends on `MyLibrarySDKCore`. |

The package currently supports iOS 15 and later and has no external package dependencies.

## Release a version

1. Commit the package source and this README to the Git repository.
2. In Xcode's package editor, confirm the repository resolves and the two products are available to a sample host app.
3. Choose a semantic version, for example `1.0.0`, and create an annotated Git tag with that exact version (`1.0.0`, without a `v` prefix).
4. Push the commit and tag to the repository.
5. Share the repository URL and version with consumers. They can select the version in Xcode or use the version requirement shown above.

Keep released tags immutable. Publish a new tag for each release so clients can resolve a reproducible version.

## License

A license has not been selected for this package yet. Add the approved license file before distributing it to third parties; the repository owner should confirm the license terms.
