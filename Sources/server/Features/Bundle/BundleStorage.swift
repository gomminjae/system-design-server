import struct Foundation.Data

/// 번들 블롭 저장소 **포트**(추상). 구현(어댑터)은 `Infrastructure/Storage/` (LocalDisk, R2).
/// 도메인은 "어디에 바이트를 넣고 빼나"라는 계약만 알고, FileManager·S3 같은 세부는 모른다.
protocol BundleStorage: Sendable {
    /// 번들 파일들을 해당 위치에 쓴다 (디렉터리 생성 포함).
    func write(_ files: [BundleFile], to location: BundleLocation) async throws

    /// 위치 안의 특정 파일을 읽는다. 없으면 nil.
    func read(_ location: BundleLocation, path: String) async throws -> Data?

    /// 위치 안의 파일 경로 목록 (어드민 미리보기 등).
    func list(_ location: BundleLocation) async throws -> [String]

    /// from의 모든 파일을 to로 복사한다 (promote: pending → published/v<n>).
    func copy(from source: BundleLocation, to destination: BundleLocation) async throws

    /// 위치의 모든 파일을 삭제한다 (pending 정리 등).
    func delete(_ location: BundleLocation) async throws

    /// 해당 파일의 공개 서빙 URL. 구현마다 다름 (로컬=localhost, R2=CDN).
    func publicURL(_ location: BundleLocation, path: String) -> String
}
