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
            let path = entry.path
            if path.hasPrefix("__MACOSX") || path.hasSuffix(".DS_Store") { continue }

            // zip-slip 방어: 디렉토리 탈출 경로면 압축 해제 전에 거부한다.
            let safePath = try BundlePath.sanitize(path)

            var entryData = Data()
            _ = try archive.extract(entry) { chunk in
                entryData.append(chunk)
            }
            files.append(BundleFile(path: safePath, data: entryData))
        }
        return files
    }
}
