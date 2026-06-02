import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get("health") { _ async in "ok" }

    // 공개 JSON API (플레이어·창작자) — 표준 응답/에러 봉투 적용
    let api = app.grouped(APIErrorMiddleware())
    try api.register(collection: CatalogController())
    try api.register(collection: SubmissionController())

    // 어드민 (Leaf SSR + Basic Auth)
    let adminUser = Environment.get("ADMIN_USER") ?? "admin"
    let adminPassword = Environment.get("ADMIN_PASSWORD") ?? "dev-password"
    if Environment.get("ADMIN_PASSWORD") == nil {
        app.logger.warning("ADMIN_PASSWORD 미설정 — 개발용 기본값(admin/dev-password) 사용 중. 운영 전 반드시 설정하세요.")
    }
    let admin = app.grouped(AdminBasicAuthMiddleware(username: adminUser, password: adminPassword))
    try admin.register(collection: AdminController())
}
