import Fluent
import Vapor
import VaporToOpenAPI

func routes(_ app: Application) throws {
    app.get("health") { _ async in "ok" }

    // Swagger UI + OpenAPI JSON
    app.get("swagger", "swagger.json") { req in
        req.application.routes.openAPI(
            info: .init(title: "System Design Server API", version: "1.0.0")
        )
    }
    app.get("swagger") { req -> Response in
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "text/html")
        return Response(status: .ok, headers: headers, body: .init(string: """
        <!DOCTYPE html>
        <html><head>
        <title>System Design Server API</title>
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
    try api.register(collection: AuthController())
    try api.register(collection: AppController())

    // 어드민 (Basic Auth)
    let adminUser = Environment.get("ADMIN_USER") ?? "admin"
    let adminPassword: String
    if let pw = Environment.get("ADMIN_PASSWORD") {
        adminPassword = pw
    } else if app.environment == .production {
        fatalError("ADMIN_PASSWORD 환경변수가 운영에 필요합니다.")
    } else {
        app.logger.warning("ADMIN_PASSWORD 미설정 — 개발용 기본값(admin/dev-password) 사용 중.")
        adminPassword = "dev-password"
    }
    let admin = app.grouped(AdminBasicAuthMiddleware(username: adminUser, password: adminPassword))
    try admin.register(collection: AppAdminController())
}
