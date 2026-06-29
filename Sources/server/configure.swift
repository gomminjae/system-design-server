import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import JWTKit
import Leaf
import NIOSSL
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    try configureDatabase(app)

    // Leaf를 뷰 렌더러로 사용 (어드민 SSR 페이지용)
    app.views.use(.leaf)

    // 인메모리 캐시 (카탈로그·화면·버전 응답 캐싱용)
    app.caches.use(.memory)

    // CORS — 웹(react-native-web) 타깃이 API를 호출할 수 있게. X-Market 커스텀 헤더 허용.
    app.middleware.use(CORSMiddleware(configuration: .init(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .init("X-Market")]
    )), at: .beginning)

    app.migrations.add(CreateTong())
    app.migrations.add(AddTongOwnerID())
    app.migrations.add(RenameTongThumbnailColumn())

    // 번들 스토리지: SUPABASE_URL+SUPABASE_SERVICE_KEY 있으면 Supabase Storage(운영),
    // 없으면 로컬 디스크(개발/테스트).
    if let supabaseURL = Environment.get("SUPABASE_URL"),
       let serviceKey = Environment.get("SUPABASE_SERVICE_KEY") {
        let projectURL = supabaseURL.hasSuffix("/") ? String(supabaseURL.dropLast()) : supabaseURL
        let bucket = Environment.get("SUPABASE_BUNDLE_BUCKET") ?? "bundles"
        app.bundleStorage = SupabaseBundleStorage(
            projectURL: projectURL, bucket: bucket, serviceKey: serviceKey, client: app.client)
    } else {
        let storageDir = app.directory.workingDirectory + "Storage/bundles"
        let baseURL = Environment.get("BASE_URL") ?? "http://localhost:8080"
        app.bundleStorage = LocalDiskBundleStorage(baseDirectory: storageDir, baseURL: baseURL)
    }

    app.migrations.add(CreateUser())
    app.migrations.add(CreateAppVersion())
    app.migrations.add(CreateScreen())
    app.migrations.add(CreateCategory())
    app.migrations.add(SeedCategories())
    // tongs.owner_id → users.id FK (users 생성 이후 실행돼야 함)
    app.migrations.add(AddTongOwnerForeignKey())
    app.migrations.add(CreateCardNews())
    app.migrations.add(CreateCardNewsPage())
    app.migrations.add(RemoveCardNewsCategory())
    app.migrations.add(AddCatalogIndexes())
    app.migrations.add(AddContentMarket())

    // JWT 서명 키. 운영은 JWT_SECRET(32바이트 이상) 필수 — 없으면 부팅 실패(fail-closed).
    // ⚠️ 소셜 로그인을 붙일 때는 이 자체검증을 Supabase Auth JWT(JWKS) 검증으로 교체할 것.
    //    현재 AuthService는 IdP 토큰을 이 로컬 HMAC 키로 검증하므로 iss/aud 미검증 상태다.
    let jwtSecret: String
    if let secret = Environment.get("JWT_SECRET"), secret.utf8.count >= 32 {
        jwtSecret = secret
    } else if app.environment == .production {
        fatalError("JWT_SECRET(32바이트 이상) 환경변수가 운영에 필요합니다.")
    } else {
        jwtSecret = "dev-jwt-secret-tongstongs"
    }
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
        var config = try SQLPostgresConfiguration(url: databaseURL)
        // Supabase pooler는 TLS 필수지만 그 인증서가 시스템 CA 체인 풀 검증을 통과하지 못한다.
        // 암호화는 유지하되 인증서 검증은 끈다.
        // ponytail: MVP 수준. 강화하려면 Supabase CA 인증서를 trust roots에 추가하고 .fullVerification.
        var tls = TLSConfiguration.makeClientConfiguration()
        tls.certificateVerification = .none
        config.coreConfiguration.tls = .require(try NIOSSLContext(configuration: tls))
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
