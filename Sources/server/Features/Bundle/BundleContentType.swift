import Vapor

/// 번들 파일 확장자 → MIME 타입 추론. 서빙(로컬)·업로드(Supabase) 양쪽에서 공용.
enum BundleContentType {
    static func mediaType(for path: String) -> HTTPMediaType {
        guard let ext = path.split(separator: ".").last else { return .plainText }
        switch ext.lowercased() {
        case "html", "htm": return .html
        case "css": return .css
        case "js", "mjs": return HTTPMediaType(type: "text", subType: "javascript")
        case "json": return .json
        case "png": return .png
        case "jpg", "jpeg": return .jpeg
        case "gif": return .gif
        case "svg": return HTTPMediaType(type: "image", subType: "svg+xml")
        case "ico": return HTTPMediaType(type: "image", subType: "x-icon")
        case "woff": return HTTPMediaType(type: "font", subType: "woff")
        case "woff2": return HTTPMediaType(type: "font", subType: "woff2")
        case "webp": return HTTPMediaType(type: "image", subType: "webp")
        default: return .plainText
        }
    }
}
