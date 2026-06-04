/// 번들 내부 상대경로 검증/정규화.
///
/// 서빙(서버 디스크 읽기)과 업로드(zip 압축 해제) 양쪽에서 디렉토리 탈출을 막는다.
/// - `..` 세그먼트, 절대경로, 백슬래시, NUL을 차단한다.
/// - `.` / 중복 슬래시는 제거해 깔끔한 상대경로로 정규화한다.
enum BundlePath {
    /// 안전한 상대경로로 정규화한다. 위험한 경로면 `APIError.validation`을 throw.
    static func sanitize(_ raw: String) throws -> String {
        guard !raw.contains("\\"), !raw.contains("\0") else {
            throw APIError.validation("잘못된 파일 경로입니다: \(raw)")
        }

        var safe: [String] = []
        for component in raw.split(separator: "/", omittingEmptySubsequences: false) {
            let c = String(component)
            if c.isEmpty || c == "." { continue }   // 중복 슬래시·`.`·절대경로 앞 슬래시 제거
            if c == ".." {
                throw APIError.validation("디렉토리 탈출 경로는 허용되지 않습니다: \(raw)")
            }
            safe.append(c)
        }

        guard !safe.isEmpty else {
            throw APIError.validation("파일 경로가 필요합니다.")
        }
        return safe.joined(separator: "/")
    }
}
