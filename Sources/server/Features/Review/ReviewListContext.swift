import Vapor

/// 심사 목록 Leaf 페이지 렌더 컨텍스트.
struct ReviewListContext: Content {
    let products: [ProductDTO]
}
