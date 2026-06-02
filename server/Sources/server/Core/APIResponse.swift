import Vapor

/// 모든 성공 JSON 응답의 봉투. `{ "data": <payload> }`.
/// (성패는 HTTP 상태코드로 구분 — body에 statusCode 중복 X. 나중에 meta 자리 확장 가능)
struct APIResponse<T: Content>: Content {
    let data: T

    init(_ data: T) {
        self.data = data
    }
}
