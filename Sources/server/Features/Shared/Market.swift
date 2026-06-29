import Vapor

/// 콘텐츠 시장 분기. UI는 시장을 모르고 데이터 레이어에서만 거른다.
enum Market: String, Codable, Sendable, CaseIterable {
    case ko
    case global
    case both

    func visible(to request: Market) -> Bool {
        self == .both || self == request
    }

    static func queryValues(for request: Market) -> [Market] {
        request == .both ? Market.allCases : [request, .both]
    }
}

extension Request {
    var market: Market {
        if let raw = headers.first(name: "X-Market"), let m = Market(rawValue: raw) { return m }
        if let raw = query[String.self, at: "market"], let m = Market(rawValue: raw) { return m }
        return .ko
    }
}
