// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "JohnnyCache",
     platforms: [
              .macOS(.v14),
              .iOS(.v16),
              .watchOS(.v10),
         ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "JohnnyCache",
            targets: ["JohnnyCache"]),
    ],
	 dependencies: [
	 ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(name: "JohnnyCache", dependencies: []),
        .testTarget(
            name: "JohnnyCacheTests",
            dependencies: ["JohnnyCache"]
        ),
    ]
)
