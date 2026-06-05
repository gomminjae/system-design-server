import Fluent
import Vapor
import VaporToOpenAPI

func routes(_ app: Application) throws {
    app.get("health") { _ async in "ok" }

    // Swagger UI + OpenAPI JSON
    app.get("swagger", "swagger.json") { req in
        req.application.routes.openAPI(
            info: .init(title: "Tongstongs API", version: "1.0.0")
        )
    }
    app.get("swagger") { req -> Response in
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "text/html")
        return Response(status: .ok, headers: headers, body: .init(string: """
        <!DOCTYPE html>
        <html><head>
        <title>Tongstongs API</title>
        <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist/swagger-ui.css">
        </head><body>
        <div id="swagger-ui"></div>
        <script src="https://unpkg.com/swagger-ui-dist/swagger-ui-bundle.js"></script>
        <script>SwaggerUIBundle({url:"/swagger/swagger.json",dom_id:"#swagger-ui"})</script>
        </body></html>
        """))
    }

    // 공개 JSON API — 표준 응답/에러 봉투 적용
    let api = app.grouped(APIErrorMiddleware())
    try api.register(collection: CatalogController())
    try api.register(collection: CategoryController())
    try api.register(collection: CardNewsController())
    try api.register(collection: SubmissionController())
    try api.register(collection: AuthController())
    try api.register(collection: AppController())
    try api.register(collection: ScreenController())

    // 번들 파일 서빙 (공개, HTML/JS/CSS)
    try app.register(collection: BundleServingController())

    // 어드민 (Leaf SSR + Basic Auth)
    let adminUser = Environment.get("ADMIN_USER") ?? "admin"
    let adminPassword = Environment.get("ADMIN_PASSWORD") ?? "dev-password"
    if Environment.get("ADMIN_PASSWORD") == nil {
        app.logger.warning("ADMIN_PASSWORD 미설정 — 개발용 기본값(admin/dev-password) 사용 중. 운영 전 반드시 설정하세요.")
    }
    let admin = app.grouped(AdminBasicAuthMiddleware(username: adminUser, password: adminPassword))
    try admin.register(collection: AdminController())
    try admin.register(collection: AppAdminController())
    try admin.register(collection: ScreenAdminController())
    try admin.register(collection: CardNewsAdminController())
}
