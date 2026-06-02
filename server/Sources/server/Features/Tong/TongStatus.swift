/// 통(Tong)의 심사/배포 상태.
/// submitted → inReview → approved(카탈로그 노출) / rejected, 그리고 approved에서 disabled(kill switch).
enum TongStatus: String, Codable, Sendable {
    case submitted
    case inReview = "in_review"
    case approved
    case rejected
    case disabled
}
