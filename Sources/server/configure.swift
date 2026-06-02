import Fluent
import FluentSQLiteDriver
import Leaf
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    app.databases.use(DatabaseConfigurationFactory.sqlite(.file("db.sqlite")), as: .sqlite)

    // Leaf를 뷰 렌더러로 사용 (어드민 SSR 페이지용)
    app.views.use(.leaf)

    app.migrations.add(CreateTong())

    // 개발 편의: 부팅 시 자동 마이그레이션
    try await app.autoMigrate()

    // register routes
    try routes(app)
}
