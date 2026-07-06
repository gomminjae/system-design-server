import Vapor
import VaporToOpenAPI
import SajuKit

/// 사주 계산 API. 생년월일시 → 원국·오행·십성·대운.
/// 만세력 계산은 SajuKit(순수 Swift). GPT 해석은 이후 단계.
struct SajuController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.post("saju", use: self.calculate)
            .openAPI(
                summary: "사주 계산",
                description: "생년월일시(양력/음력) → 사주팔자·오행·십성·대운.",
                body: .type(SajuRequest.self),
                response: .type(APIResponse<SajuDTO>.self)
            )
    }

    @Sendable
    func calculate(req: Request) async throws -> APIResponse<SajuDTO> {
        let body = try req.content.decode(SajuRequest.self)
        do {
            let result = try Saju.calculate(body.toInput)
            return APIResponse(SajuDTO(result))
        } catch let error as SajuError {
            throw Abort(.badRequest, reason: error.message)
        }
    }
}
