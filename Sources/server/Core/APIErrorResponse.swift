import Vapor

/// 모든 실패 JSON 응답의 봉투. `{ "error": { "code", "message" } }`.
struct APIErrorResponse: Content {
    struct Body: Content {
        let code: String     // 기계 판별용 (예: "not_found")
        let message: String  // 사람용 메시지
    }
    let error: Body
}
