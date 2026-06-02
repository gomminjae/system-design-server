import Vapor

/// 통 반려(POST /admin/tongs/:id/reject) 입력. 어드민 폼에서 form-urlencoded로 들어온다.
struct RejectRequest: Content {
    var reason: String
}
