import Fluent
import Vapor

/// API로 나가는 통(Tong) 표현. DB 모델(Tong)과 분리해 내부 구조를 노출하지 않는다.
struct TongDTO: Content {
    var id: UUID?
    var type: String
    var title: String
    var subtitle: String?
    var thumbnailURL: String?
    var bundleURL: String
    var version: String
    var category: String
    var ageRating: String
    var market: Market
    var status: TongStatus
    var rejectionReason: String?
    var createdAt: Date?
}
