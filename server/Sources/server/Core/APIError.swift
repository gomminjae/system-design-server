import Vapor

/// 도메인 에러 — HTTP 상태 + 기계용 코드 + 사람용 메시지를 운반.
/// `AbortError` 채택이라 throw 하면 `APIErrorMiddleware`가 표준 봉투로 변환한다.
struct APIError: Error, AbortError {
    let status: HTTPResponseStatus
    let code: String
    let reason: String   // AbortError 요구사항 (= 사람용 메시지)

    static func notFound(_ message: String) -> APIError {
        .init(status: .notFound, code: "not_found", reason: message)
    }

    static func validation(_ message: String) -> APIError {
        .init(status: .badRequest, code: "validation", reason: message)
    }

    static func unauthorized(_ message: String = "인증이 필요합니다.") -> APIError {
        .init(status: .unauthorized, code: "unauthorized", reason: message)
    }
}
