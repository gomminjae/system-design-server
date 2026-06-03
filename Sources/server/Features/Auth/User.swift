import Fluent
import struct Foundation.UUID
import struct Foundation.Date

/// 유저. 소셜 로그인(Apple/Kakao)으로 생성된다.
final class User: Model, @unchecked Sendable {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    /// 소셜 프로바이더: "apple" | "kakao"
    @Field(key: "provider")
    var provider: String

    /// 프로바이더 측 유저 고유 ID (Apple: sub, Kakao: id)
    @Field(key: "provider_id")
    var providerID: String

    @OptionalField(key: "nickname")
    var nickname: String?

    @OptionalField(key: "profile_image_url")
    var profileImageURL: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        provider: String,
        providerID: String,
        nickname: String? = nil,
        profileImageURL: String? = nil
    ) {
        self.id = id
        self.provider = provider
        self.providerID = providerID
        self.nickname = nickname
        self.profileImageURL = profileImageURL
    }
}
