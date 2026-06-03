import Vapor

/// 심사 큐 Leaf 페이지 렌더 컨텍스트.
struct ReviewQueueContext: Content {
    let tongs: [TongDTO]
}
