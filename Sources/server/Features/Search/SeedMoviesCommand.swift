import Fluent
import Vapor

/// `swift run server seed-movies [--count 10000]`
/// 합성 영화 카탈로그 시드. KOBIS 실데이터 연동 전까지의 실험용 코퍼스.
/// 관객수는 Zipf 분포 — 실제 검색/흥행 트래픽처럼 상위 소수가 대부분을 차지해야 캐싱 실험이 의미 있다.
struct SeedMoviesCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Option(name: "count", help: "생성할 영화 수 (기본 10000)")
        var count: Int?
    }

    var help: String { "합성 영화 데이터를 movies 테이블에 시드한다." }

    // 조합으로 유니크한 제목을 만들기 위한 재료. prefix가 자연스럽게 겹치도록 접두어 풀을 좁게 유지.
    private static let prefixes = [
        "아이언", "어벤져스", "스파이더", "배트", "슈퍼", "캡틴", "닥터", "미션",
        "인터", "인셉", "매트릭", "터미네이", "트랜스", "쥬라기", "해리", "반지",
        "스타", "다크", "블랙", "화이트", "레드", "골든", "실버", "라스트",
        "퍼스트", "파이널", "이터널", "인피니", "위대한", "지금은", "그해", "우리들의",
    ]
    private static let suffixes = [
        "맨", "워즈", "월드", "킹덤", "게임", "히어로", "나이트", "데이",
        "러브", "스토리", "시티", "하우스", "로드", "리턴즈", "라이징", "포에버",
        "비밀", "전쟁", "여름", "겨울", "약속", "시간", "기억", "여행",
    ]

    func run(using context: CommandContext, signature: Signature) async throws {
        let db = context.application.db
        let target = signature.count ?? 10_000

        let existing = try await Movie.query(on: db).count()
        guard existing == 0 else {
            context.console.warning("movies에 이미 \(existing)건 있음 — 시드 생략. 다시 넣으려면 테이블을 비우세요.")
            return
        }

        var rng = SystemRandomNumberGenerator()
        var movies: [Movie] = []
        movies.reserveCapacity(target)
        for rank in 1...target {
            let p = Self.prefixes[Int.random(in: 0..<Self.prefixes.count, using: &rng)]
            let s = Self.suffixes[Int.random(in: 0..<Self.suffixes.count, using: &rng)]
            let numbered = rank % 3 == 0 ? " \(rank % 9 + 1)" : ""
            // Zipf: audience ≈ C / rank^0.9 — 1위 천만, 꼬리는 수백 명대.
            let audience = Int(10_000_000.0 / pow(Double(rank), 0.9))
            movies.append(Movie(
                title: "\(p) \(s)\(numbered)",
                releaseYear: Int.random(in: 1990...2026, using: &rng),
                audienceCount: max(audience, 100)
            ))
        }

        // 배치 insert — 한 건씩 넣으면 왕복 비용으로 수십 배 느리다.
        for chunk in movies.chunks(ofCount: 500) {
            try await Array(chunk).create(on: db)
        }
        context.console.success("영화 \(target)건 시드 완료.")
    }
}

private extension Array {
    func chunks(ofCount size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
