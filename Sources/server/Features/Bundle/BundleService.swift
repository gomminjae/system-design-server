import Vapor
import Foundation

/// 번들 업로드, 검증, 저장, 승격 비즈니스 로직.
struct BundleService {
    let storage: any BundleStorage

    /// zip 데이터를 검증하고 pending 경로에 저장한다.
    func upload(productId: UUID, zipData: Data) async throws -> String {
        let files = try ZipExtractor.extract(from: zipData)

        guard files.contains(where: { $0.path == "index.html" }) else {
            throw APIError.validation("번들 루트에 index.html이 필요합니다.")
        }

        let location = BundleLocation.pending(productId: productId)
        try await storage.write(files, to: location)

        return storage.publicURL(location, path: "index.html")
    }

    /// pending 번들을 published로 승격 (심사 승인 시).
    func promote(productId: UUID, version: String) async throws -> String {
        let pending = BundleLocation.pending(productId: productId)
        let published = BundleLocation.published(productId: productId, version: version)

        let pendingFiles = try await storage.list(pending)
        guard !pendingFiles.isEmpty else {
            throw APIError.validation("업로드된 번들이 없습니다.")
        }

        try await storage.copy(from: pending, to: published)
        try await storage.delete(pending)

        return storage.publicURL(published, path: "index.html")
    }

    /// pending 번들 삭제 (반려 시 정리).
    func cleanupPending(productId: UUID) async throws {
        try await storage.delete(BundleLocation.pending(productId: productId))
    }

    /// 번들 파일 읽기 (서빙용).
    func readFile(location: BundleLocation, path: String) async throws -> Data {
        guard let data = try await storage.read(location, path: path) else {
            throw APIError.notFound("파일을 찾을 수 없습니다.")
        }
        return data
    }
}
