import Vapor

/// 소셜 로그인 요청 (통합).
struct SocialLoginRequest: Content {
    let provider: String   // "apple" | "kakao"
    let idToken: String    // OIDC id_token (JWT)
    let nickname: String?  // 최초 가입 시 (Apple은 첫 로그인에만 이름 제공)
}

/// 로그인 응답 — 자체 JWT + 유저 정보.
struct AuthResponse: Content {
    let token: String
    let user: UserDTO
}

/// 유저 공개 정보.
struct UserDTO: Content {
    var id: UUID?
    var provider: String
    var nickname: String?
    var profileImageURL: String?
}
