// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "server",
    platforms: [
       .macOS(.v13)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.115.0"),
        // 🗄 An ORM for SQL and NoSQL databases.
        .package(url: "https://github.com/vapor/fluent.git", from: "4.9.0"),
        // 🪶 Fluent driver for SQLite. (테스트·로컬 폴백용)
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.6.0"),
        // 🐘 Fluent driver for PostgreSQL. (개발/운영용)
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.8.0"),
        // 🍃 Leaf 템플릿 엔진 (어드민 SSR 페이지용).
        .package(url: "https://github.com/vapor/leaf.git", from: "4.3.0"),
        // 🔵 Non-blocking, event-driven networking for Swift. Used for custom executors
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        // 🌊 스트리밍 HTTP 클라이언트 (SSE 무당 해석용). Vapor의 req.client는 응답을 버퍼링해서 스트리밍 불가.
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.35.0"),
        // 📦 ZIP 아카이브 읽기/쓰기 (번들 업로드용).
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0"),
        // 🔐 JWT 인증 (Apple Sign In 토큰 검증 + 자체 토큰 발급).
        .package(url: "https://github.com/vapor/jwt.git", from: "5.0.0"),
        // 📖 Swagger/OpenAPI 문서 자동 생성.
        .package(url: "https://github.com/dankinsoid/VaporToOpenAPI.git", from: "4.8.1"),
        // 🔮 만세력/사주 계산 엔진 (순수 Swift). 항상 최신 main을 바라본다.
        // Docker 빌드는 build 단계에서 `swift package update SajuKit`으로 최신을 강제(캐시 staleness 방지) — Dockerfile 참고.
        .package(url: "https://github.com/Formant-Silo/SajuKit.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "server",
            dependencies: [
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "Leaf", package: "leaf"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
                .product(name: "JWT", package: "jwt"),
                .product(name: "VaporToOpenAPI", package: "VaporToOpenAPI"),
                .product(name: "SajuKit", package: "SajuKit"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "serverTests",
            dependencies: [
                .target(name: "server"),
                .product(name: "VaporTesting", package: "vapor"),
            ],
            swiftSettings: swiftSettings
        )
    ]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("ExistentialAny"),
] }
