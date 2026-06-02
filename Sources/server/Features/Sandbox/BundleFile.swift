import struct Foundation.Data

/// 번들 안의 파일 하나.
/// `path`는 번들 루트 기준 상대경로 (예: "index.html", "assets/bg.png").
struct BundleFile: Sendable {
    let path: String
    let data: Data
}
