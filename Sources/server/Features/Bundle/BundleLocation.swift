import struct Foundation.UUID

/// 번들이 사는 위치.
/// - pending: 심사 전 (비공개)
/// - published: 승인본, 버전 고정(불변)
enum BundleLocation: Sendable {
    case pending(tongId: UUID)
    case published(tongId: UUID, version: String)
}
