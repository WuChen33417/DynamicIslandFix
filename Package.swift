// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "DynamicIslandCore", products: [.library(name: "DynamicIslandCore", targets: ["DynamicIslandCore"])], targets: [
    .target(name: "DynamicIslandCore", path: "YumEdit/IslandCore"),
    .testTarget(name: "DynamicIslandCoreTests", dependencies: ["DynamicIslandCore"])
])
