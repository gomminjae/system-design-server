import Fluent
import Vapor

/// 통 제출(POST /submissions) 입력. 출력(TongDTO)과 분리해 "받을 필드"만 통제한다.
/// status·rejectionReason 등은 서버가 정하지 클라이언트가 못 정한다.
///
/// NOTE: `bundleURL`은 지금은 문자열로 직접 받지만, 파일 업로드 단계에서
/// 서버가 zip을 저장·서빙하며 id 기반 경로로 자동 생성하는 값으로 대체된다. (임시)
struct TongSubmission: Content {
    var type: String
    var title: String
    var subtitle: String?
    var thumbURL: String?
    var bundleURL: String
    var version: String
    var category: String
    var ageRating: String
    var submitterContact: String?

    func toModel() -> Tong {
        Tong(
            type: type,
            title: title,
            subtitle: subtitle,
            thumbURL: thumbURL,
            bundleURL: bundleURL,
            version: version,
            category: category,
            ageRating: ageRating,
            status: .submitted,
            submitterContact: submitterContact
        )
    }
}
