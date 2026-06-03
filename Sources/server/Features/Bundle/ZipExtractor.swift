import Foundation
@preconcurrency import ZIPFoundation

/// zip 바이트를 [BundleFile]로 변환. macOS 메타데이터는 제외.
enum ZipExtractor {
    static func extract(from data: Data) throws -> [BundleFile] {
        guard let archive = Archive(data: data, accessMode: .read) else {
            throw APIError.validation("유효한 zip 파일이 아닙니다.")
        }

        var files: [BundleFile] = []
        for entry in archive where entry.type == .file {
            var entryData = Data()
            _ = try archive.extract(entry) { chunk in
                entryData.append(chunk)
            }
            let path = entry.path
            if path.hasPrefix("__MACOSX") || path.hasSuffix(".DS_Store") { continue }
            files.append(BundleFile(path: path, data: entryData))
        }
        return files
    }
}
