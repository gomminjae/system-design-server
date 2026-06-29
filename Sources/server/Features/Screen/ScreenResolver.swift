import Vapor

/// SDUI 동적 바인딩. 저장된 섹션의 참조(categorySlug, tongId)를
/// `GET /screens` 시점에 실제 카탈로그/카테고리 데이터로 채워(hydrate) 내려준다.
///
/// - `tong_list` + `categorySlug` → 해당 카테고리 승인 통으로 items 채움
/// - `tong_card` / `tong_detail` + `tongId` → 실제 통에서 빈 필드만 채움(어드민 입력값 우선)
/// - `category_chips` → 항상 Category 테이블로 chips 생성
struct ScreenResolver {
    let tongs: any TongRepository
    let categories: CategoryService
    let cardNews: any CardNewsRepository

    func resolve(_ sections: [Section], market: Market) async throws -> [Section] {
        // card/detail이 참조하는 통 id를 모아 한 번에 조회(N+1 방지).
        let referencedIDs = sections.compactMap { section -> UUID? in
            guard section.type == .tongCard || section.type == .tongDetail else { return nil }
            return section.data.tongId.flatMap(UUID.init(uuidString:))
        }
        let tongsByID = try await tongs.approvedByIDs(referencedIDs)

        // 각 섹션을 병렬로 resolve (독립적인 DB 쿼리를 동시에 실행).
        let resolved = try await withThrowingTaskGroup(of: (Int, Section).self) { group in
            for (index, section) in sections.enumerated() {
                group.addTask {
                    let result: Section
                    switch section.type {
                    case .tongList:
                        result = try await resolveTongList(section, market: market)
                    case .tongCard, .tongDetail:
                        result = resolveTongRef(section, tongsByID: tongsByID, market: market)
                    case .categoryChips:
                        result = try await resolveChips(section)
                    case .cardNewsList:
                        result = try await resolveCardNewsList(section, market: market)
                    case .cardNewsCard:
                        result = try await resolveCardNewsCard(section, market: market)
                    default:
                        result = section
                    }
                    return (index, result)
                }
            }
            var ordered = Array(repeating: sections[0], count: sections.count)
            for try await (index, section) in group {
                ordered[index] = section
            }
            return ordered
        }
        // 동적 리스트가 비면(해당 market에 콘텐츠 없음) 섹션 자체를 숨긴다.
        return resolved.filter { !isEmptyDynamicList($0) }
    }

    private func isEmptyDynamicList(_ section: Section) -> Bool {
        guard let slug = section.data.categorySlug, !slug.isEmpty else { return false }
        switch section.type {
        case .tongList: return section.data.items?.isEmpty ?? true
        case .cardNewsList: return section.data.cardNewsItems?.isEmpty ?? true
        default: return false
        }
    }

    /// card_news_list: categorySlug 지정 시 발행 카드뉴스로 cardNewsItems 채움.
    private func resolveCardNewsList(_ section: Section, market: Market) async throws -> Section {
        guard let slug = section.data.categorySlug, !slug.isEmpty else { return section }
        let limit = section.data.limit ?? 10
        let items = try await cardNews.published(category: slug, market: market, after: nil, limit: limit)
            .prefix(limit)
            .map { $0.toCardNewsItem() }
        var data = section.data
        data.cardNewsItems = Array(items)
        return Section(id: section.id, type: section.type, data: data, action: section.action)
    }

    /// card_news_card: cardNewsId로 발행 카드뉴스에서 빈 필드만 채운다(어드민 오버라이드 우선).
    private func resolveCardNewsCard(_ section: Section, market: Market) async throws -> Section {
        guard let idString = section.data.cardNewsId,
              let id = UUID(uuidString: idString),
              let cn = try await cardNews.findPublished(id),
              cn.market.visible(to: market) else { return section }

        var data = section.data
        if isBlank(data.title) { data.title = cn.title }
        if isBlank(data.subtitle) { data.subtitle = cn.subtitle }
        if isBlank(data.thumbnailURL) {
            data.thumbnailURL = cn.thumbnailURL ?? cn.pages.sorted { $0.pageIndex < $1.pageIndex }.first?.imageURL
        }
        return Section(id: section.id, type: section.type, data: data, action: section.action)
    }

    /// tong_list: categorySlug 지정 시 승인 통으로 items 채움. 미지정이면 정적 items 유지.
    private func resolveTongList(_ section: Section, market: Market) async throws -> Section {
        guard let slug = section.data.categorySlug, !slug.isEmpty else { return section }
        let limit = section.data.limit ?? 10
        let items = try await tongs.getApproved(category: slug, market: market, after: nil, limit: limit).map { $0.toItem() }
        var data = section.data
        data.items = items
        return Section(id: section.id, type: section.type, data: data, action: section.action)
    }

    /// tong_card / tong_detail: 실제 통에서 비어 있는 필드만 채운다(어드민 오버라이드 우선).
    private func resolveTongRef(_ section: Section, tongsByID: [UUID: Tong], market: Market) -> Section {
        guard let idString = section.data.tongId,
              let id = UUID(uuidString: idString),
              let tong = tongsByID[id],
              tong.market.visible(to: market) else { return section }

        var data = section.data
        if isBlank(data.title) { data.title = tong.title }
        if isBlank(data.subtitle) { data.subtitle = tong.subtitle }
        if isBlank(data.thumbnailURL) { data.thumbnailURL = tong.thumbnailURL }
        if isBlank(data.bundleURL) { data.bundleURL = tong.bundleURL }
        if data.categoryEmoji == nil { data.categoryEmoji = CategoryEmoji.of(tong.category) }

        var action = section.action
        if var existing = action, isBlank(existing.bundleURL) {
            existing.bundleURL = tong.bundleURL
            if isBlank(existing.tongId) { existing.tongId = idString }
            action = existing
        }
        return Section(id: section.id, type: section.type, data: data, action: action)
    }

    /// category_chips: 항상 Category 테이블로 chips 생성. 맨 앞에 "전체" 칩 추가.
    private func resolveChips(_ section: Section) async throws -> Section {
        let cats = try await categories.list()
        var chips = [CategoryChip(id: "all", label: "전체")]
        chips.append(contentsOf: cats.map { CategoryChip(id: $0.slug, label: $0.name) })

        var data = section.data
        data.chips = chips
        if isBlank(data.selectedId) { data.selectedId = "all" }
        return Section(id: section.id, type: section.type, data: data, action: section.action)
    }

    private func isBlank(_ value: String?) -> Bool {
        (value ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }
}

extension Tong {
    /// SDUI tong_list 카드 항목으로 변환.
    func toItem() -> TongItem {
        TongItem(
            tongId: self.id?.uuidString ?? "",
            title: self.title,
            subtitle: self.subtitle,
            thumbnailURL: self.thumbnailURL,
            badge: nil,
            categoryEmoji: CategoryEmoji.of(self.category),
            bundleURL: self.bundleURL
        )
    }
}

extension CardNews {
    /// SDUI card_news_list 항목으로 변환.
    func toCardNewsItem() -> CardNewsItem {
        CardNewsItem(
            cardNewsId: self.id?.uuidString ?? "",
            title: self.title,
            subtitle: self.subtitle,
            thumbnailURL: self.thumbnailURL,
            pageCount: self.pageCount
        )
    }
}
