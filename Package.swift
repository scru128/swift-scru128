// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "swift-scru128",
  products: [.library(name: "Scru128", targets: ["Scru128"])],
  dependencies: [],
  targets: [
    .target(name: "Scru128", dependencies: []),
    .testTarget(name: "Scru128Tests", dependencies: ["Scru128"]),
  ]
)
