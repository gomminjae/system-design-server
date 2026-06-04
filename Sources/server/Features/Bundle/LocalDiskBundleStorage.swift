import Foundation

/// 로컬 디스크 기반 BundleStorage 구현체.
/// 개발/스테이징용. 운영은 R2 어댑터로 교체.
struct LocalDiskBundleStorage: BundleStorage {
    let baseDirectory: String
    let baseURL: String

    func write(_ files: [BundleFile], to location: BundleLocation) async throws {
        let dir = directory(for: location)
        try FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true
        )
        for file in files {
            let safePath = try BundlePath.sanitize(file.path)
            let filePath = dir + "/" + safePath
            let parentDir = (filePath as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(
                atPath: parentDir, withIntermediateDirectories: true
            )
            try file.data.write(to: URL(fileURLWithPath: filePath))
        }
    }

    func read(_ location: BundleLocation, path: String) async throws -> Data? {
        let safePath = try BundlePath.sanitize(path)
        let filePath = directory(for: location) + "/" + safePath
        return FileManager.default.contents(atPath: filePath)
    }

    func list(_ location: BundleLocation) async throws -> [String] {
        let dir = directory(for: location)
        guard let enumerator = FileManager.default.enumerator(atPath: dir) else { return [] }
        var paths: [String] = []
        while let path = enumerator.nextObject() as? String {
            var isDir: ObjCBool = false
            let fullPath = dir + "/" + path
            if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir),
               !isDir.boolValue {
                paths.append(path)
            }
        }
        return paths
    }

    func copy(from source: BundleLocation, to destination: BundleLocation) async throws {
        let srcDir = directory(for: source)
        let dstDir = directory(for: destination)
        try FileManager.default.createDirectory(
            atPath: dstDir, withIntermediateDirectories: true
        )
        let files = try await list(source)
        for file in files {
            let srcPath = srcDir + "/" + file
            let dstPath = dstDir + "/" + file
            let parentDir = (dstPath as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(
                atPath: parentDir, withIntermediateDirectories: true
            )
            try FileManager.default.copyItem(atPath: srcPath, toPath: dstPath)
        }
    }

    func delete(_ location: BundleLocation) async throws {
        let dir = directory(for: location)
        if FileManager.default.fileExists(atPath: dir) {
            try FileManager.default.removeItem(atPath: dir)
        }
    }

    func publicURL(_ location: BundleLocation, path: String) -> String {
        switch location {
        case .pending(let tongId):
            return "\(baseURL)/bundles/pending/\(tongId.uuidString)/\(path)"
        case .published(let tongId, let version):
            return "\(baseURL)/bundles/\(tongId.uuidString)/v\(version)/\(path)"
        }
    }

    private func directory(for location: BundleLocation) -> String {
        switch location {
        case .pending(let tongId):
            return "\(baseDirectory)/pending/\(tongId.uuidString)"
        case .published(let tongId, let version):
            return "\(baseDirectory)/published/\(tongId.uuidString)/v\(version)"
        }
    }
}
