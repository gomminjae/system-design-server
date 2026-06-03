import Vapor
import VaporToOpenAPI

/// 소셜 로그인 엔드포인트.
struct AuthController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        auth.post("login", use: self.login)
            .openAPI(
                summary: "소셜 로그인",
                description: "Apple/Kakao OIDC id_token으로 로그인하고 자체 JWT를 발급받는다.",
                body: .type(SocialLoginRequest.self),
                response: .type(AuthResponse.self)
            )
        auth.get("me", use: self.me)
            .openAPI(
                summary: "내 정보 조회",
                description: "Bearer 토큰으로 현재 로그인된 유저 정보를 조회한다.",
                response: .type(APIResponse<UserDTO>.self)
            )
    }

    /// POST /auth/login — 소셜 로그인 통합 엔드포인트.
    /// body: { "provider": "apple" | "kakao", "idToken": "..." }
    @Sendable
    func login(req: Request) async throws -> AuthResponse {
        let body = try req.content.decode(SocialLoginRequest.self)
        return try await req.authService.login(provider: body.provider, idToken: body.idToken, nickname: body.nickname)
    }

    /// GET /auth/me — 현재 로그인된 유저 정보.
    @Sendable
    func me(req: Request) async throws -> APIResponse<UserDTO> {
        let payload = try await req.jwt.verify(as: UserJWTPayload.self)
        guard let userId = UUID(uuidString: payload.subject.value) else {
            throw APIError.unauthorized()
        }
        guard let user = try await req.userRepository.find(userId) else {
            throw APIError.notFound("유저를 찾을 수 없습니다.")
        }
        return APIResponse(user.toDTO())
    }
}
