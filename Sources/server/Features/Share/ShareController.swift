import Fluent
import Vapor

/// 공유 랜딩. 콘텐츠 HTML에 OG 메타를 주입해 text/html로 서빙한다.
/// → 카톡/소셜에 미리보기 카드가 뜨고, 링크를 누르면 실제 콘텐츠가 브라우저에서 실행된다.
/// (Supabase Storage는 HTML을 text/plain으로 주므로, 공유 링크는 이 라우트를 거친다.)
struct ShareController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("share", ":productID", use: self.share)
    }

    @Sendable
    func share(req: Request) async throws -> Response {
        let id = try req.parameters.require("productID", as: UUID.self)
        guard let product = try await Product.query(on: req.db)
            .filter(\.$id == id)
            .filter(\.$status == .approved)
            .first() else {
            throw APIError.notFound("콘텐츠를 찾을 수 없습니다.")
        }

        let clientRes = try await req.client.get(URI(string: product.bundleURL))
        guard var html = clientRes.body.map({ String(buffer: $0) }), !html.isEmpty else {
            throw APIError(status: .badGateway, code: "bundle_fetch_failed", reason: "콘텐츠를 불러올 수 없습니다.")
        }

        let title = esc(product.title)
        let desc = esc(product.subtitle ?? "1분이면 너가 보여 — Cosmi")
        let image = product.thumbnailURL ?? ""
        let shareURL = "https://tongstongs-server.fly.dev/share/\(id)"
        let meta = """
        <meta property="og:type" content="website">
        <meta property="og:title" content="\(title)">
        <meta property="og:description" content="\(desc)">
        <meta property="og:image" content="\(esc(image))">
        <meta property="og:url" content="\(shareURL)">
        <meta name="twitter:card" content="summary_large_image">
        <meta name="twitter:title" content="\(title)">
        <meta name="twitter:image" content="\(esc(image))">

        """

        if let head = html.range(of: "</head>") {
            html.replaceSubrange(head, with: meta + "</head>")
        } else {
            html = "<head>\(meta)</head>" + html
        }

        var headers = HTTPHeaders()
        headers.contentType = .html
        headers.cacheControl = .init(maxAge: 300)
        return Response(status: .ok, headers: headers, body: .init(string: html))
    }

    private func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
