import Fluent
import struct Foundation.UUID
import struct Foundation.Date

/// 통(Tong) = 자기완결형 콘텐츠 한 개. Phase 0 매니페스트를 그대로 코드화한 것.
/// 카탈로그(승인본)와 심사 대기본을 status 하나로 같이 다룬다.
///
/// `@ID` property wrapper가 `Sendable` 체크와 충돌하므로 템플릿 관례대로 `@unchecked Sendable`로 둔다.
final class Tong: Model, @unchecked Sendable {
    static let schema = "tongs"

    @ID(key: .id)
    var id: UUID?

    /// quiz | game | tool | fortune — 호스트는 분류 태그로만 쓰고 실행은 전부 웹이 한다.
    @Field(key: "type")
    var type: String

    @Field(key: "title")
    var title: String

    @OptionalField(key: "subtitle")
    var subtitle: String?

    @OptionalField(key: "thumb_url")
    var thumbURL: String?

    /// 번들 위치. CRUD 단계선 임시 문자열, 업로드 붙으면 id 기반 저장소 경로로 대체.
    @Field(key: "bundle_url")
    var bundleURL: String

    /// 승인 단위. 새 버전 = 재심사.
    @Field(key: "version")
    var version: String

    /// personality | love | fortune ... 디스커버리용 분류.
    @Field(key: "category")
    var category: String

    /// all | 12 | 15 | 17
    @Field(key: "age_rating")
    var ageRating: String

    @Field(key: "status")
    var status: TongStatus

    /// 반려 사유 (status == .rejected 일 때 채워짐).
    @OptionalField(key: "rejection_reason")
    var rejectionReason: String?

    /// 제출자 연락처(이메일/닉네임). 반려 피드백용. V2 계정 붙기 전 임시.
    @OptionalField(key: "submitter_contact")
    var submitterContact: String?

    /// 제출한 유저(소유자). 번들 업로드 소유자 검증·"내 제출 목록"에 쓴다.
    /// 계정 인증 이전에 생성된 통은 nil. (FK 컬럼: owner_id)
    /// id만 필요하면 `$owner.id`로 User 로드 없이 접근, 객체는 `.with(\.$owner)`로 eager load.
    @OptionalParent(key: "owner_id")
    var owner: User?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        type: String,
        title: String,
        subtitle: String? = nil,
        thumbURL: String? = nil,
        bundleURL: String,
        version: String,
        category: String,
        ageRating: String,
        status: TongStatus = .submitted,
        submitterContact: String? = nil,
        ownerID: UUID? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.thumbURL = thumbURL
        self.bundleURL = bundleURL
        self.version = version
        self.category = category
        self.ageRating = ageRating
        self.status = status
        self.submitterContact = submitterContact
        self.$owner.id = ownerID
    }

    func toDTO() -> TongDTO {
        .init(
            id: self.id,
            type: self.type,
            title: self.title,
            subtitle: self.subtitle,
            thumbURL: self.thumbURL,
            bundleURL: self.bundleURL,
            version: self.version,
            category: self.category,
            ageRating: self.ageRating,
            status: self.status,
            rejectionReason: self.rejectionReason,
            createdAt: self.createdAt
        )
    }
}
