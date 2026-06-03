import Vapor
import JWT

/// 소셜 로그인 + JWT 발급 비즈니스 로직.
struct AuthService {
    let repository: any UserRepository
    let app: Application

    /// provider별 OIDC id_token을 검증하고 유저를 생성/조회한 뒤 자체 JWT를 발급한다.
    func login(provider: String, idToken: String, nickname: String?) async throws -> AuthResponse {
        let providerID: String

        switch provider {
        case "apple":
            let payload = try await app.jwt.keys.verify(idToken, as: AppleIdentityToken.self)
            providerID = payload.subject.value
        case "kakao":
            let payload = try await app.jwt.keys.verify(idToken, as: KakaoIdentityToken.self)
            providerID = payload.subject.value
        default:
            throw APIError.validation("지원하지 않는 provider입니다: \(provider)")
        }

        let user = try await findOrCreateUser(
            provider: provider,
            providerID: providerID,
            nickname: nickname
        )

        let token = try await generateToken(for: user)
        return AuthResponse(token: token, user: user.toDTO())
    }

    private func findOrCreateUser(
        provider: String,
        providerID: String,
        nickname: String? = nil
    ) async throws -> User {
        if let existing = try await repository.findByProvider(provider, providerID: providerID) {
            if let nickname { existing.nickname = nickname }
            try await repository.save(existing)
            return existing
        }

        let user = User(
            provider: provider,
            providerID: providerID,
            nickname: nickname
        )
        try await repository.save(user)
        return user
    }

    private func generateToken(for user: User) async throws -> String {
        guard let userId = user.id else {
            throw Abort(.internalServerError)
        }
        let payload = UserJWTPayload(
            subject: .init(value: userId.uuidString),
            expiration: .init(value: .distantFuture)
        )
        return try await app.jwt.keys.sign(payload)
    }
}

/// 자체 JWT 페이로드.
struct UserJWTPayload: JWTPayload {
    var subject: SubjectClaim
    var expiration: ExpirationClaim

    func verify(using algorithm: some JWTAlgorithm) async throws {
        try self.expiration.verifyNotExpired()
    }
}

/// Apple OIDC id_token 페이로드.
struct AppleIdentityToken: JWTPayload {
    var subject: SubjectClaim
    var expiration: ExpirationClaim
    var issuer: IssuerClaim
    var audience: AudienceClaim

    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case expiration = "exp"
        case issuer = "iss"
        case audience = "aud"
    }

    func verify(using algorithm: some JWTAlgorithm) async throws {
        try self.expiration.verifyNotExpired()
    }
}

/// Kakao OIDC id_token 페이로드.
struct KakaoIdentityToken: JWTPayload {
    var subject: SubjectClaim
    var expiration: ExpirationClaim
    var issuer: IssuerClaim
    var audience: AudienceClaim

    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case expiration = "exp"
        case issuer = "iss"
        case audience = "aud"
    }

    func verify(using algorithm: some JWTAlgorithm) async throws {
        try self.expiration.verifyNotExpired()
    }
}

extension User {
    func toDTO() -> UserDTO {
        UserDTO(
            id: self.id,
            provider: self.provider,
            nickname: self.nickname,
            profileImageURL: self.profileImageURL
        )
    }
}
