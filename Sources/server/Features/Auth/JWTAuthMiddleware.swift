import Vapor
import JWT

/// Bearer JWT 토큰을 검증하는 미들웨어.
/// 인증이 필요한 라우트 그룹에 적용한다.
struct JWTAuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        do {
            let payload = try await request.jwt.verify(as: UserJWTPayload.self)
            // 검증된 유저 ID를 request storage에 저장
            request.storage[AuthenticatedUserKey.self] = UUID(uuidString: payload.subject.value)
        } catch {
            throw APIError.unauthorized("유효하지 않은 토큰입니다.")
        }
        return try await next.respond(to: request)
    }
}

/// 인증된 유저 ID를 request에서 꺼내는 키.
struct AuthenticatedUserKey: StorageKey {
    typealias Value = UUID
}

extension Request {
    /// 인증된 유저 ID. JWTAuthMiddleware 통과 후 사용 가능.
    var authenticatedUserID: UUID {
        get throws {
            guard let id = self.storage[AuthenticatedUserKey.self] else {
                throw APIError.unauthorized()
            }
            return id
        }
    }
}
