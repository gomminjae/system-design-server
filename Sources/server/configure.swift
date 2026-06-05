import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import JWTKit
import Leaf
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    try configureDatabase(app)

    // Leaf를 뷰 렌더러로 사용 (어드민 SSR 페이지용)
    app.views.use(.leaf)

    // 인메모리 캐시 (카탈로그·화면·버전 응답 캐싱용)
    app.caches.use(.memory)

    app.migrations.add(CreateTong())
    app.migrations.add(AddTongOwnerID())
    app.migrations.add(RenameTongThumbnailColumn())

    // 번들 스토리지 (로컬 디스크)
    let storageDir = app.directory.workingDirectory + "Storage/bundles"
    let baseURL = Environment.get("BASE_URL") ?? "http://localhost:8080"
    app.bundleStorage = LocalDiskBundleStorage(baseDirectory: storageDir, baseURL: baseURL)

    app.migrations.add(CreateUser())
    app.migrations.add(CreateAppVersion())
    app.migrations.add(CreateScreen())
    app.migrations.add(CreateCategory())
    app.migrations.add(SeedCategories())
    // tongs.owner_id → users.id FK (users 생성 이후 실행돼야 함)
    app.migrations.add(AddTongOwnerForeignKey())

    // JWT 서명 키 (개발용 HMAC, 운영은 RSA/EC로 교체)
    let jwtSecret = Environment.get("JWT_SECRET") ?? "dev-jwt-secret-tongstongs"
    await app.jwt.keys.add(hmac: HMACKey(from: jwtSecret), digestAlgorithm: .sha256)

    // 개발/테스트 편의: 부팅 시 자동 마이그레이션.
    // 운영(production)은 배포 파이프라인에서 `migrate --yes`로 따로 실행한다.
    if app.environment != .production {
        try await app.autoMigrate()
    }

    // register routes
    try routes(app)
}

/// 환경별 데이터베이스 설정.
/// - `.testing`: 인메모리 SQLite (격리·고속)
/// - `DATABASE_URL` 지정: 그 URL의 Postgres (운영/클라우드)
/// - 그 외: 로컬 Postgres (기본값: localhost / $USER / tongstongs)
private func configureDatabase(_ app: Application) throws {
    if app.environment == .testing {
        app.databases.use(.sqlite(.memory), as: .sqlite)
        return
    }

    if let databaseURL = Environment.get("DATABASE_URL") {
        // sslmode 등 TLS 옵션은 URL 쿼리(?sslmode=require)로 전달한다.
        let config = try SQLPostgresConfiguration(url: databaseURL)
        app.databases.use(.postgres(configuration: config), as: .psql)
        return
    }

    let config = SQLPostgresConfiguration(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init) ?? 5433,
        username: Environment.get("DATABASE_USERNAME") ?? "tongstongs",
        password: Environment.get("DATABASE_PASSWORD") ?? "tongstongs",
        database: Environment.get("DATABASE_NAME") ?? "tongstongs",
        tls: .disable
    )
    app.databases.use(.postgres(configuration: config), as: .psql)
}
