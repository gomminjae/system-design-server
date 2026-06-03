import Fluent
import FluentSQLiteDriver
import JWTKit
import Leaf
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    app.databases.use(DatabaseConfigurationFactory.sqlite(.file("db.sqlite")), as: .sqlite)

    // Leaf를 뷰 렌더러로 사용 (어드민 SSR 페이지용)
    app.views.use(.leaf)

    app.migrations.add(CreateTong())

    // 번들 스토리지 (로컬 디스크)
    let storageDir = app.directory.workingDirectory + "Storage/bundles"
    let baseURL = Environment.get("BASE_URL") ?? "http://localhost:8080"
    app.bundleStorage = LocalDiskBundleStorage(baseDirectory: storageDir, baseURL: baseURL)

    app.migrations.add(CreateUser())
    app.migrations.add(CreateAppVersion())

    // JWT 서명 키 (개발용 HMAC, 운영은 RSA/EC로 교체)
    let jwtSecret = Environment.get("JWT_SECRET") ?? "dev-jwt-secret-tongstongs"
    await app.jwt.keys.add(hmac: HMACKey(from: jwtSecret), digestAlgorithm: .sha256)

    // 개발 편의: 부팅 시 자동 마이그레이션
    try await app.autoMigrate()

    // register routes
    try routes(app)
}
