import Vapor
import VaporToOpenAPI
import SajuKit

/// 무당 해석 API. 사주 계산(SajuKit) → 페르소나 프롬프트 조립 → GPT 해석.
/// `OPENAI_API_KEY` 없으면 조립된 프롬프트를 그대로 반환(dry-run).
struct SajuReadingController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.post("saju", "reading", use: self.reading)
            .openAPI(
                summary: "무당 사주 해석",
                description: "생년월일시 + 무당(persona) + tier(free/paid) → GPT 해석. 키 없으면 dry-run.",
                body: .type(ReadingRequest.self),
                response: .type(APIResponse<ReadingResponse>.self)
            )
    }

    @Sendable
    func reading(req: Request) async throws -> APIResponse<ReadingResponse> {
        let body = try req.content.decode(ReadingRequest.self)
        guard let persona = Personas.all[body.persona] else {
            throw Abort(.badRequest, reason: "알 수 없는 무당: \(body.persona) (ghost | money)")
        }
        let paid = (body.tier ?? "free") == "paid"

        let result: SajuResult
        do { result = try Saju.calculate(body.toInput) }
        catch let error as SajuError { throw Abort(.badRequest, reason: error.message) }

        let messages = [
            ChatMessage(role: "system", content: persona.system + "\n\n" + persona.instruction(paid: paid)),
            ChatMessage(role: "user", content: "아래는 이미 정확히 계산된 사주 데이터다. 이 데이터만 근거로 풀어라.\n\n" + SajuFormatter.text(result)),
        ]

        // 키 없으면 조립된 프롬프트 반환 (dry-run)
        guard let apiKey = Environment.get("OPENAI_API_KEY") else {
            return APIResponse(ReadingResponse(
                persona: persona.name, tier: paid ? "paid" : "free",
                dryRun: true, reading: nil, messages: messages, saju: SajuDTO(result)))
        }

        let model = Environment.get("OPENAI_MODEL") ?? "gpt-4o"
        let res = try await req.client.post("https://api.openai.com/v1/chat/completions") { out in
            out.headers.bearerAuthorization = .init(token: apiKey)
            try out.content.encode(OpenAIChatRequest(model: model, messages: messages))
        }
        guard res.status == .ok else {
            throw Abort(.badGateway, reason: "OpenAI 오류: \(res.status)")
        }
        let decoded = try res.content.decode(OpenAIChatResponse.self)
        return APIResponse(ReadingResponse(
            persona: persona.name, tier: paid ? "paid" : "free",
            dryRun: false, reading: decoded.choices.first?.message.content, messages: nil, saju: SajuDTO(result)))
    }
}

// MARK: - DTOs

struct ReadingRequest: Content {
    let year: Int
    let month: Int
    let day: Int
    let hour: Int?
    let minute: Int?
    let gender: String?
    let calendar: String?
    let leap: Bool?
    let longitude: Double?
    let applyLocalMeanTime: Bool?
    let persona: String   // "ghost" | "money"
    let tier: String?     // "free" | "paid" (기본 free)

    var toInput: SajuInput {
        SajuInput(
            year: year, month: month, day: day, hour: hour, minute: minute,
            gender: gender.flatMap(Gender.init(rawValue:)),
            calendar: calendar.flatMap(CalendarType.init(rawValue:)),
            leap: leap, longitude: longitude, applyLocalMeanTime: applyLocalMeanTime)
    }
}

struct ChatMessage: Content { let role: String; let content: String }

struct ReadingResponse: Content {
    let persona: String
    let tier: String
    let dryRun: Bool
    let reading: String?          // GPT 해석 (호출 시)
    let messages: [ChatMessage]?  // 조립된 프롬프트 (dry-run 시)
    let saju: SajuDTO
}

struct OpenAIChatRequest: Content {
    let model: String
    let messages: [ChatMessage]
}
struct OpenAIChatResponse: Content {
    struct Choice: Content { struct Message: Content { let content: String }; let message: Message }
    let choices: [Choice]
}
