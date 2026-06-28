import Foundation
import Vapor

/// Supabase Storage(REST) 기반 BundleStorage 구현체.
///
/// 버킷은 **public**이어야 한다. `publicURL`이 Supabase CDN을 직접 가리켜
/// 통 콘텐츠 다운로드가 앱 서버를 우회한다(서버 egress 0).
/// 무거운 S3 SDK 대신 Vapor 내장 `Client`로 Storage REST API를 직접 호출한다.
struct SupabaseBundleStorage: BundleStorage {
    let projectURL: String   // 예: https://xxx.supabase.co (끝 슬래시 없음)
    let bucket: String
    let serviceKey: String
    let client: any Client

    // ponytail: list/copy/delete는 prefix당 최대 1000개 항목까지. 번들 한 개가
    // 그 이상 파일을 가지면 페이지네이션(offset)을 추가해야 함.
    private static let listLimit = 1000

    func write(_ files: [BundleFile], to location: BundleLocation) async throws {
        let base = prefix(for: location)
        for file in files {
            let safePath = try BundlePath.sanitize(file.path)
            try await put(key: "\(base)/\(safePath)", data: file.data, contentTypePath: safePath)
        }
    }

    func read(_ location: BundleLocation, path: String) async throws -> Data? {
        let safePath = try BundlePath.sanitize(path)
        let key = "\(prefix(for: location))/\(safePath)"
        let res = try await client.get(uri("/storage/v1/object/\(bucket)/\(key)")) { req in
            sign(&req)
        }
        if res.status == .notFound { return nil }
        guard res.status == .ok, let body = res.body else {
            throw Abort(.internalServerError, reason: "Supabase read 실패 \(key): \(res.status)")
        }
        return Data(body.readableBytesView)
    }

    func list(_ location: BundleLocation) async throws -> [String] {
        let base = prefix(for: location)
        return try await listRecursive(prefix: base, base: base)
    }

    func copy(from source: BundleLocation, to destination: BundleLocation) async throws {
        let srcBase = prefix(for: source)
        let dstBase = prefix(for: destination)
        for relative in try await list(source) {
            try await copyObject(srcKey: "\(srcBase)/\(relative)", dstKey: "\(dstBase)/\(relative)")
        }
    }

    func delete(_ location: BundleLocation) async throws {
        let base = prefix(for: location)
        let keys = (try await list(location)).map { "\(base)/\($0)" }
        guard !keys.isEmpty else { return }
        let res = try await client.delete(uri("/storage/v1/object/\(bucket)")) { req in
            sign(&req)
            try req.content.encode(PrefixesBody(prefixes: keys))
        }
        guard res.status == .ok else {
            throw Abort(.internalServerError, reason: "Supabase delete 실패 \(base): \(res.status)")
        }
    }

    func publicURL(_ location: BundleLocation, path: String) -> String {
        "\(projectURL)/storage/v1/object/public/\(bucket)/\(prefix(for: location))/\(path)"
    }

    // MARK: - 내부

    private func prefix(for location: BundleLocation) -> String {
        switch location {
        case .pending(let tongId):
            return "pending/\(tongId.uuidString)"
        case .published(let tongId, let version):
            return "published/\(tongId.uuidString)/v\(version)"
        }
    }

    private func uri(_ path: String) -> URI { URI(string: projectURL + path) }

    /// 모든 요청에 인증 헤더를 단다. 새 `sb_secret_` 키는 `apikey` 헤더가 필요하고,
    /// 레거시 `service_role` 키도 동일 값으로 동작한다.
    private func sign(_ req: inout ClientRequest) {
        req.headers.bearerAuthorization = .init(token: serviceKey)
        req.headers.replaceOrAdd(name: "apikey", value: serviceKey)
    }

    private func put(key: String, data: Data, contentTypePath: String) async throws {
        var buffer = ByteBuffer()
        buffer.writeBytes(data)
        let res = try await client.post(uri("/storage/v1/object/\(bucket)/\(key)")) { req in
            sign(&req)
            req.headers.replaceOrAdd(name: "x-upsert", value: "true")  // 멱등 업로드(재배포·재심사)
            req.headers.contentType = BundleContentType.mediaType(for: contentTypePath)
            req.body = buffer
        }
        guard res.status == .ok || res.status == .created else {
            throw Abort(.internalServerError, reason: "Supabase upload 실패 \(key): \(res.status)")
        }
    }

    private func copyObject(srcKey: String, dstKey: String) async throws {
        let res = try await client.post(uri("/storage/v1/object/copy")) { req in
            sign(&req)
            try req.content.encode(CopyBody(bucketId: bucket, sourceKey: srcKey, destinationKey: dstKey))
        }
        guard res.status == .ok else {
            throw Abort(.internalServerError, reason: "Supabase copy 실패 \(srcKey)→\(dstKey): \(res.status)")
        }
    }

    /// `base` 기준 상대경로 목록을 재귀로 수집한다. Supabase list는 한 레벨만 반환하므로
    /// 폴더(id == nil)는 다시 내려간다.
    private func listRecursive(prefix: String, base: String) async throws -> [String] {
        let res = try await client.post(uri("/storage/v1/object/list/\(bucket)")) { req in
            sign(&req)
            try req.content.encode(ListBody(prefix: prefix + "/", limit: Self.listLimit))
        }
        guard res.status == .ok else {
            throw Abort(.internalServerError, reason: "Supabase list 실패 \(prefix): \(res.status)")
        }
        let objects = try res.content.decode([StorageObject].self)
        var result: [String] = []
        for obj in objects {
            let full = "\(prefix)/\(obj.name)"
            if obj.id == nil {
                result += try await listRecursive(prefix: full, base: base)  // 폴더
            } else {
                result.append(String(full.dropFirst(base.count + 1)))         // base 기준 상대경로
            }
        }
        return result
    }

    private struct StorageObject: Content {
        let name: String
        let id: String?   // 폴더는 null
    }
    private struct ListBody: Content { let prefix: String; let limit: Int }
    private struct CopyBody: Content { let bucketId: String; let sourceKey: String; let destinationKey: String }
    private struct PrefixesBody: Content { let prefixes: [String] }
}
