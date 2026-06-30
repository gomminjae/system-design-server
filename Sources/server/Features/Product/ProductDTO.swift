import Fluent
import Vapor

/// API로 나가는 콘텐츠(Product) 표현. DB 모델(Product)과 분리해 내부 구조를 노출하지 않는다.
struct ProductDTO: Content {
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
    var status: ProductStatus
    var rejectionReason: String?
    var createdAt: Date?
}
