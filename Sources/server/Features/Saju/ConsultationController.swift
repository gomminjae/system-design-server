import Vapor
import Fluent
import VaporToOpenAPI
import SajuKit
import struct Foundation.Date
import struct Foundation.Calendar

/// 결정 상담 API. 손님이 결제하고 무당에게 콕 집어 묻는 자리.
/// 흐름: 상담 시작(세션 생성) → 질문(질문마다 사주+세운+이전대화 → GPT) → 내역 조회.
/// 질문 수는 서버가 카운트해 결제 게이팅을 지킨다.
struct ConsultationController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let base = routes.grouped("saju", "consultation")
        base.post(use: self.start)
            .openAPI(summary: "결정 상담 시작",
                     description: "사주+무당+(결제) → 상담 세션 생성. 질문권 부여.",
                     body: .type(StartRequest.self),
                     response: .type(APIResponse<StartResponse>.self))
        base.post(":id", "ask", use: self.ask)
            .openAPI(summary: "무당에게 질문",
                     description: "고민(A/B 또는 단일)을 물으면 사주+올해 기운으로 콕 집어 답한다. 질문권 1개 차감.",
                     body: .type(AskRequest.self),
                     response: .type(APIResponse<AskResponse>.self))
        base.get(":id", use: self.history)
            .openAPI(summary: "상담 내역",
                     response: .type(APIResponse<HistoryResponse>.self))
    }

    // MARK: - POST /saju/consultation

    @Sendable
    func start(req: Request) async throws -> APIResponse<StartResponse> {
        let body = try req.content.decode(StartRequest.self)
        guard Personas.all[body.persona] != nil else {
            throw Abort(.badRequest, reason: "알 수 없는 무당: \(body.persona) (ghost | money)")
        }
        // 입력 오류(잘못된 날짜 등)를 상담 생성 전에 조기 차단.
        do { _ = try Saju.calculate(body.toInput) }
        catch let error as SajuError { throw Abort(.badRequest, reason: error.message) }

        let c = Consultation()
        c.year = body.year; c.month = body.month; c.day = body.day
        c.hour = body.hour; c.minute = body.minute
        c.gender = body.gender; c.calendar = body.calendar; c.leap = body.leap
        c.longitude = body.longitude; c.applyLocalMeanTime = body.applyLocalMeanTime
        c.persona = body.persona
        c.questionsAllowed = body.questionsAllowed ?? 5   // 결제 붙기 전 기본값
        c.questionsUsed = 0
        c.orderRef = body.orderRef
        try await c.save(on: req.db)

        return APIResponse(StartResponse(
            id: try c.requireID(), persona: c.persona,
            questionsAllowed: c.questionsAllowed, questionsRemaining: c.questionsRemaining))
    }

    // MARK: - POST /saju/consultation/:id/ask

    @Sendable
    func ask(req: Request) async throws -> APIResponse<AskResponse> {
        let id = try req.parameters.require("id", as: UUID.self)
        let body = try req.content.decode(AskRequest.self)
        let question = body.question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { throw Abort(.badRequest, reason: "질문이 비어 있습니다.") }

        guard let c = try await Consultation.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "상담을 찾을 수 없습니다.")
        }
        guard c.questionsRemaining > 0 else {
            throw Abort(.paymentRequired, reason: "남은 질문이 없습니다.")
        }
        guard let persona = Personas.all[c.persona] else {
            throw Abort(.badRequest, reason: "알 수 없는 무당: \(c.persona)")
        }

        let result = try Saju.calculate(c.toInput)
        let prior = try await c.$turns.query(on: req.db).sort(\.$createdAt, .ascending).all()
        let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())

        // 프롬프트: 페르소나 + 콕 집는 심리 + 결정 상담 틀 → 사주+세운 → 이전 문답 → 이번 질문
        let system = persona.system + "\n\n" + Personas.readingCraft + "\n\n" + Personas.consultationCraft
        var messages: [ChatMessage] = [
            ChatMessage(role: "system", content: system),
            ChatMessage(role: "user", content:
                "아래는 이미 정확히 계산된 이 손님의 사주다. 이 데이터만 근거로 답하라.\n\n"
                + SajuFormatter.ageLine(birthYear: c.year) + "\n"
                + SajuFormatter.text(result) + "\n\n"
                + SajuFormatter.annualText(dayStemIndex: result.pillars.day.stemIndex, fromYear: currentYear)),
        ]
        for t in prior {
            messages.append(ChatMessage(role: "user", content: t.question))
            messages.append(ChatMessage(role: "assistant", content: t.answer))
        }
        messages.append(ChatMessage(role: "user", content: Self.askPrompt(body, question: question)))

        // 키 없을 때: 운영은 준비 중, 개발은 조립 프롬프트 반환(튜닝용). 질문권 차감·저장 안 함.
        guard let apiKey = Environment.get("OPENAI_API_KEY") else {
            if req.application.environment == .production {
                throw Abort(.serviceUnavailable, reason: "무당 상담 서비스 준비 중입니다.")
            }
            return APIResponse(AskResponse(
                answer: nil, dryRun: true, messages: messages,
                questionsRemaining: c.questionsRemaining))
        }

        let call = LLMCall.consult
        let res = try await req.client.post("https://api.openai.com/v1/chat/completions") { out in
            out.headers.bearerAuthorization = .init(token: apiKey)
            try out.content.encode(OpenAIChatRequest(model: call.model, messages: messages, maxTokens: call.maxTokens))
        }
        guard res.status == .ok else {
            throw Abort(.badGateway, reason: "OpenAI 오류: \(res.status)")
        }
        let decoded = try res.content.decode(OpenAIChatResponse.self)
        guard let answer = decoded.choices.first?.message.content else {
            throw Abort(.badGateway, reason: "무당이 답을 내지 못했습니다.")
        }

        // 성공 시에만 문답 저장 + 질문권 차감.
        let turn = ConsultationTurn()
        turn.$consultation.id = try c.requireID()
        turn.question = question
        turn.answer = answer
        turn.mode = "decision"
        turn.optionA = body.optionA
        turn.optionB = body.optionB
        try await turn.save(on: req.db)

        c.questionsUsed += 1
        try await c.save(on: req.db)

        return APIResponse(AskResponse(
            answer: answer, dryRun: false, messages: nil,
            questionsRemaining: c.questionsRemaining))
    }

    // MARK: - GET /saju/consultation/:id

    @Sendable
    func history(req: Request) async throws -> APIResponse<HistoryResponse> {
        let id = try req.parameters.require("id", as: UUID.self)
        guard let c = try await Consultation.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "상담을 찾을 수 없습니다.")
        }
        let turns = try await c.$turns.query(on: req.db).sort(\.$createdAt, .ascending).all()
        return APIResponse(HistoryResponse(
            id: try c.requireID(), persona: c.persona,
            questionsAllowed: c.questionsAllowed, questionsRemaining: c.questionsRemaining,
            turns: turns.map { TurnDTO(question: $0.question, answer: $0.answer,
                                       optionA: $0.optionA, optionB: $0.optionB) }))
    }

    /// 이번 질문을 무당에게 넘길 형태로. A/B면 두 갈래를 명시한다.
    private static func askPrompt(_ b: AskRequest, question: String) -> String {
        if let a = b.optionA, let bb = b.optionB {
            return "[결정 상담] 손님의 고민: \(question)\n- A: \(a)\n- B: \(bb)\n"
                + "두 갈래를 놓고 사주와 올해 기운으로 콕 집어 답해다오."
        }
        return "[결정 상담] 손님의 물음: \(question)\n사주와 올해 기운을 근거로 콕 집어 답해다오."
    }
}

// MARK: - DTOs

struct StartRequest: Content {
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
    let persona: String            // "ghost" | "money"
    let questionsAllowed: Int?     // 결제로 채움. 없으면 기본 5.
    let orderRef: String?          // 결제 참조. 지금은 옵션.

    var toInput: SajuInput {
        SajuInput(
            year: year, month: month, day: day, hour: hour, minute: minute,
            gender: gender.flatMap(Gender.init(rawValue:)),
            calendar: calendar.flatMap(CalendarType.init(rawValue:)),
            leap: leap, longitude: longitude, applyLocalMeanTime: applyLocalMeanTime)
    }
}

struct StartResponse: Content {
    let id: UUID
    let persona: String
    let questionsAllowed: Int
    let questionsRemaining: Int
}

struct AskRequest: Content {
    let question: String
    let optionA: String?   // 두 갈래 고민의 선택지 A (선택)
    let optionB: String?   // 두 갈래 고민의 선택지 B (선택)
}

struct AskResponse: Content {
    let answer: String?           // 무당 답변 (호출 시)
    let dryRun: Bool
    let messages: [ChatMessage]?  // 조립된 프롬프트 (dry-run 시)
    let questionsRemaining: Int
}

struct HistoryResponse: Content {
    let id: UUID
    let persona: String
    let questionsAllowed: Int
    let questionsRemaining: Int
    let turns: [TurnDTO]
}

struct TurnDTO: Content {
    let question: String
    let answer: String
    let optionA: String?
    let optionB: String?
}
