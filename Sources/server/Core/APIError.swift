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

    static func forbidden(_ message: String = "권한이 없습니다.") -> APIError {
        .init(status: .forbidden, code: "forbidden", reason: message)
    }

    static func preconditionFailed(code: String, message: String) -> APIError {
        .init(status: .preconditionFailed, code: code, reason: message)
    }

    static func internalServerError(_ message: String = "서버 오류가 발생했어요.") -> APIError {
        .init(status: .internalServerError, code: "internal_error", reason: message)
    }
}
