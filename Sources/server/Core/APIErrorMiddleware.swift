import Vapor

/// JSON API 그룹에서 던져진 에러를 표준 봉투(APIErrorResponse)로 변환한다.
/// 어드민(Leaf/HTML)에는 적용하지 않는다 — JSON API 그룹에만 붙인다.
struct APIErrorMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        do {
            return try await next.respond(to: request)
        } catch {
            let status: HTTPResponseStatus
            let code: String
            let message: String

            if let apiError = error as? APIError {
                status = apiError.status
                code = apiError.code
                message = apiError.reason
            } else if let abort = error as? any AbortError {
                status = abort.status
                code = "error"
                message = abort.reason
            } else {
                status = .internalServerError
                code = "internal_error"
                message = "서버 오류가 발생했어요."
            }

            let response = Response(status: status)
            try response.content.encode(APIErrorResponse(error: .init(code: code, message: message)))
            return response
        }
    }
}
