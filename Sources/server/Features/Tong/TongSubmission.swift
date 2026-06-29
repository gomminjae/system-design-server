import Fluent
import Vapor

/// 통 제출(POST /submissions) 입력. 출력(TongDTO)과 분리해 "받을 필드"만 통제한다.
/// status·rejectionReason 등은 서버가 정하지 클라이언트가 못 정한다.
///
/// 통 제출 입력. bundleURL은 번들 업로드 후 서버가 채운다.
struct TongSubmission: Content {
    var type: String
    var title: String
    var subtitle: String?
    var thumbnailURL: String?
    var bundleURL: String?
    var version: String
    var category: String
    var ageRating: String
    var market: Market?
    var submitterContact: String?

    func toModel() -> Tong {
        Tong(
            type: type,
            title: title,
            subtitle: subtitle,
            thumbnailURL: thumbnailURL,
            bundleURL: bundleURL ?? "",
            version: version,
            category: category,
            ageRating: ageRating,
            market: market ?? .ko,
            status: .submitted,
            submitterContact: submitterContact
        )
    }
}

/// 번들 업로드(POST /submissions/:id/bundle) 입력.
struct BundleUpload: Content {
    let file: File
}
