import Vapor

/// `/admin/*` 보호 — Basic Auth.
/// 브라우저가 로그인 팝업을 띄우도록 401 응답에 `WWW-Authenticate`를 붙인다.
/// 관리자는 나 혼자라 User 시스템 없이 ID/PW 한 쌍으로 충분. (나중에 이 미들웨어만 교체)
struct AdminBasicAuthMiddleware: AsyncMiddleware {
    let username: String
    let password: String

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        if let basic = request.headers.basicAuthorization,
           basic.username == username,
           basic.password == password {
            return try await next.respond(to: request)
        }

        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: "WWW-Authenticate", value: "Basic realm=\"admin\"")
        return Response(status: .unauthorized, headers: headers, body: .init(string: "인증이 필요합니다."))
    }
}
