// swift-tools-version: 6.1

//
//  Package.swift
//  NemoAPI
//
//  Created by Jeongcheol Kim on 7/14/26.
//  Copyright (c) 2026 Jeongcheol Kim (nemois). All rights reserved.
//
//  Licensed under the MIT License.
//  See the LICENSE file in the project root for license information.
//

import PackageDescription

/// Platform floors match the stdlib's `Duration` (macOS 13 / iOS 16), which `APIEndpoint.ttl` exposes.
let package = Package(
    name: "NemoAPI",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "NemoAPI",
            targets: ["NemoAPI"]
        ),
    ],
    targets: [
        .target(
            name: "NemoAPI",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .testTarget(
            name: "NemoAPITests",
            dependencies: ["NemoAPI"]
        ),
    ]
)
