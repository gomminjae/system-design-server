import Foundation
import Vapor
import AsyncHTTPClient
import NIOCore
import SajuKit

/// 무당 해석 SSE 스트리밍. `/saju/reading/stream`.
/// OpenAI를 stream=true로 부르고 토큰을 곧장 클라로 relay하면서, 완성 텍스트는 끝에 캐시(tee)한다.
/// Vapor의 `req.client`는 응답을 버퍼링하므로 스트리밍엔 AsyncHTTPClient(shared)를 직접 쓴다.
extension SajuReadingController {

    /// JSON 엔드포인트와 스트리밍 엔드포인트가 공유하는 캐시 키.
    static func cacheID(for i: ReadingRequest) -> String {
        "\(i.persona):\(i.tier ?? "free"):\(i.year).\(i.month).\(i.day).\(i.hour ?? -1).\(i.minute ?? -1).\(i.gender ?? "").\(i.calendar ?? "solar").\(i.leap ?? false).\(i.longitude ?? 0).\(i.applyLocalMeanTime ?? false)"
    }

    @Sendable
    func readingStream(req: Request) async throws -> Response {
        let body = try req.content.decode(ReadingRequest.self)
        let cacheID = Self.cacheID(for: body)
        let persona = try Personas.require(body.persona)
        let paid = (body.tier ?? "free") == "paid"

        let result: SajuResult
        do { result = try Saju.calculate(body.toInput) }
        catch let error as SajuError { throw Abort(.badRequest, reason: error.message) }
        let sajuDTO = SajuDTO(result)

        // 캐시 히트: 저장된 해석을 한 이벤트로 재생 → 클라 처리 일원화, GPT 안 부름.
        if let cached = try await req.cache.get(ReadingResponse.self, id: cacheID),
           let text = cached.reading {
            return Self.sse { writer in
                try? await Self.send(writer, .init(delta: text))
                try? await Self.send(writer, .init(done: true))
            }
        }

        // 키 없을 때: 운영은 준비 중(정상 상태코드), 개발은 한 이벤트로 안내(파이프라인 테스트용).
        guard let apiKey = Environment.get("OPENAI_API_KEY") else {
            if req.application.environment == .production {
                throw Abort(.serviceUnavailable, reason: "무당 해석 서비스 준비 중입니다.")
            }
            return Self.sse { writer in
                try? await Self.send(writer, .init(error: "OPENAI_API_KEY 미설정 (dev dry-run)"))
                try? await Self.send(writer, .init(done: true))
            }
        }

        let call: LLMCall = paid ? .full : .teaser
        let messages = [
            ChatMessage(role: "system", content: persona.readingSystem(paid: paid)),
            ChatMessage(role: "user", content: "아래는 이미 정확히 계산된 사주 데이터다. 이 데이터만 근거로 풀어라.\n\n" + SajuFormatter.ageLine(birthYear: body.year) + "\n" + SajuFormatter.text(result)),
        ]

        // OpenAI 스트리밍 요청. execute는 헤더 수신까지 대기 → 여기서 실패하면 스트림 전에 정상 HTTP 에러로 반환.
        var httpReq = HTTPClientRequest(url: "https://api.openai.com/v1/chat/completions")
        httpReq.method = .POST
        httpReq.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        httpReq.headers.add(name: "Content-Type", value: "application/json")
        httpReq.body = .bytes(try JSONEncoder().encode(
            OpenAIStreamRequest(model: call.model, messages: messages, maxTokens: call.maxTokens)))

        let openai = try await req.application.http.client.shared.execute(httpReq, timeout: .seconds(120))
        guard openai.status == .ok else {
            throw Abort(.badGateway, reason: "OpenAI 오류: \(openai.status)")
        }

        let personaName = persona.name
        return Self.sse { writer in
            var full = ""
            var lineBuf = ""       // 청크가 SSE 라인 중간에서 끊길 수 있어 라인 조립용
            var clientGone = false

            for try await chunk in openai.body {
                lineBuf += String(buffer: chunk)
                while let nl = lineBuf.firstIndex(of: "\n") {
                    let line = String(lineBuf[..<nl])
                    lineBuf = String(lineBuf[lineBuf.index(after: nl)...])
                    guard let delta = Self.parseSSELine(line) else { continue }
                    full += delta
                    if !clientGone {
                        // 클라가 끊기면 쓰기만 멈추고 OpenAI는 끝까지 받아 캐시에 남긴다(tee).
                        do { try await Self.send(writer, .init(delta: delta)) }
                        catch { clientGone = true }
                    }
                }
            }

            if !clientGone { try? await Self.send(writer, .init(done: true)) }

            // tee: 완성 텍스트를 JSON 엔드포인트와 같은 키로 캐시(24h) → 다음 동일 요청은 GPT 안 부름.
            if !full.isEmpty {
                let resp = ReadingResponse(
                    persona: personaName, tier: paid ? "paid" : "free",
                    dryRun: false, reading: full, messages: nil, saju: sajuDTO)
                try? await req.cache.set(resp, id: cacheID, expiresIn: .seconds(60 * 60 * 24))
            }
        }
    }

    // MARK: - SSE helpers

    /// text/event-stream 응답을 만든다. 클로저가 반환되면 스트림이 닫히고, throw하면 에러로 끝난다(managed).
    private static func sse(_ work: @escaping @Sendable (any AsyncBodyStreamWriter) async throws -> Void) -> Response {
        let response = Response(status: .ok)
        response.headers.replaceOrAdd(name: .contentType, value: "text/event-stream")
        response.headers.replaceOrAdd(name: .cacheControl, value: "no-cache")
        response.headers.replaceOrAdd(name: .connection, value: "keep-alive")
        response.headers.replaceOrAdd(name: "X-Accel-Buffering", value: "no")  // nginx 등 프록시 버퍼링 방지
        response.body = .init(managedAsyncStream: work)
        return response
    }

    /// SSE 이벤트 한 줄: `data: {json}\n\n`.
    private static func send(_ writer: any AsyncBodyStreamWriter, _ event: StreamEvent) async throws {
        let json = try JSONEncoder().encode(event)
        var buf = ByteBufferAllocator().buffer(capacity: json.count + 8)
        buf.writeString("data: ")
        buf.writeBytes(json)
        buf.writeString("\n\n")
        try await writer.writeBuffer(buf)
    }

    /// OpenAI SSE 한 줄에서 delta content를 뽑는다. data 라인이 아니거나 [DONE]/빈 줄이면 nil.
    private static func parseSSELine(_ raw: String) -> String? {
        let line = raw.hasSuffix("\r") ? String(raw.dropLast()) : raw
        guard line.hasPrefix("data:") else { return nil }
        let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
        guard !payload.isEmpty, payload != "[DONE]" else { return nil }
        guard let data = payload.data(using: .utf8),
              let chunk = try? JSONDecoder().decode(OpenAIStreamChunk.self, from: data)
        else { return nil }
        return chunk.choices.first?.delta.content
    }
}

// MARK: - Wire types

/// 클라로 보내는 SSE 이벤트. nil 필드는 인코딩에서 생략(synthesized encodeIfPresent).
struct StreamEvent: Encodable {
    var delta: String? = nil
    var done: Bool? = nil
    var error: String? = nil
}

/// OpenAI chat completions 스트리밍 요청 (stream=true 고정).
private struct OpenAIStreamRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let maxTokens: Int?
    var stream: Bool = true

    enum CodingKeys: String, CodingKey {
        case model, messages, stream
        case maxTokens = "max_tokens"
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(model, forKey: .model)
        try c.encode(messages, forKey: .messages)
        try c.encode(stream, forKey: .stream)
        try c.encodeIfPresent(maxTokens, forKey: .maxTokens)  // nil이면 생략(무료 티저만 캡)
    }
}

/// OpenAI 스트리밍 청크의 delta 조각.
private struct OpenAIStreamChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable { let content: String? }
        let delta: Delta
    }
    let choices: [Choice]
}
