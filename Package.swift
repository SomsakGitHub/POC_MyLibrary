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
        .binaryTarget(name: "MyLibrarySDKCoreBinary", url: "https://github.com/SomsakGitHub/POC_MyLibrary/releases/download/v0.1.1/MyLibrarySDKCoreBinary-0.1.1.zip", checksum: "43266e81564f954867524d0512c96f7f622d3827d4c4ba0f74c1378038f6afa1"),
        .binaryTarget(name: "MyLibrarySDKFeatureBinary", url: "https://github.com/SomsakGitHub/POC_MyLibrary/releases/download/v0.1.1/MyLibrarySDKFeatureBinary-0.1.1.zip", checksum: "9835ef7b43384b76199c4a831d57a246203ae953637d0c2d2d802aa9d9e743b8"),
    ]
)
