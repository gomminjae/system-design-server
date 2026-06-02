import Vapor

/// 심사 큐 Leaf 페이지(queue.leaf) 렌더 컨텍스트.
struct AdminQueueContext: Content {
    let tongs: [TongDTO]
}
