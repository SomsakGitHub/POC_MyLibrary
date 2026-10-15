// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyLibrary",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "MyLibrarySDKCore", targets: ["MyLibrarySDKCoreBinary"]),
        // Include Core so selecting the feature product links both frameworks.
        .library(name: "MyLibrarySDKFeature", targets: ["MyLibrarySDKFeatureBinary", "MyLibrarySDKCoreBinary"]),
    ],
    targets: [
        .binaryTarget(name: "MyLibrarySDKCoreBinary", url: "https://github.com/SomsakGitHub/POC_MyLibrary/releases/download/v0.1.0/MyLibrarySDKCoreBinary-0.1.0.zip", checksum: "5b19e53701441dba4c622b99dfad9807983ad851a1fd5a252167afd02644d9d2"),
        .binaryTarget(name: "MyLibrarySDKFeatureBinary", url: "https://github.com/SomsakGitHub/POC_MyLibrary/releases/download/v0.1.0/MyLibrarySDKFeatureBinary-0.1.0.zip", checksum: "dde19f60a1a683f299ebed5a7a2c0d8b5e117ce74d901f0b022d8b48cac7e5a0"),
    ]
)
