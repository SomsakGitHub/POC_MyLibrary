// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyLibrary",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(name: "MyLibrarySDKCore", targets: ["MyLibrarySDKCoreBinary"]),
        .library(name: "MyLibrarySDKFeature", targets: ["MyLibrarySDKFeatureBinary"]),
    ],
    targets: [
        .target(
            name: "MyLibrarySDKCoreBinary",
            path: "MyLibrarySDKCore/Sources"
        ),
        .target(
            name: "MyLibrarySDKFeatureBinary",
            dependencies: ["MyLibrarySDKCoreBinary"],
            path: "MyLibrarySDKFeature/Sources"
        ),
        .testTarget(
            name: "MyLibrarySDKCoreTests",
            dependencies: ["MyLibrarySDKCoreBinary"],
            path: "MyLibrarySDKCore/Tests"
        ),
    ]
)
