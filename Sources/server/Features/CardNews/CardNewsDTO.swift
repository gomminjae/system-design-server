import Vapor
import struct Foundation.UUID
import struct Foundation.Date

/// 카드뉴스 목록 항목 (페이지 본문 제외, pageCount만).
struct CardNewsListItem: Content {
    var id: UUID?
    var title: String
    var subtitle: String?
    var thumbnailURL: String?
    var category: String
    var pageCount: Int
    var isSponsored: Bool
    var sponsorName: String?
    var isPremium: Bool
    var createdAt: Date?
}

/// 카드 한 장 표현.
struct CardNewsPageDTO: Content {
    var pageIndex: Int
    var imageURL: String
    var title: String?
    var body: String?
    var bgColor: String?
}

/// 카드뉴스 상세 (페이지 전체 포함).
struct CardNewsDetailDTO: Content {
    var id: UUID?
    var title: String
    var subtitle: String?
    var thumbnailURL: String?
    var category: String
    var pageCount: Int
    var isSponsored: Bool
    var sponsorName: String?
    var sponsorLink: String?
    var isPremium: Bool
    var pages: [CardNewsPageDTO]
    var createdAt: Date?
}

extension CardNews {
    func toListItem() -> CardNewsListItem {
        .init(
            id: self.id,
            title: self.title,
            subtitle: self.subtitle,
            thumbnailURL: self.thumbnailURL,
            category: self.category,
            pageCount: self.pageCount,
            isSponsored: self.isSponsored,
            sponsorName: self.sponsorName,
            isPremium: self.isPremium,
            createdAt: self.createdAt
        )
    }

    /// 페이지가 eager load 된 상태에서 호출. (page_index 오름차순 정렬)
    func toDetail() -> CardNewsDetailDTO {
        let pages = self.pages
            .sorted { $0.pageIndex < $1.pageIndex }
            .map { $0.toDTO() }
        // 대표 이미지 폴백: thumbnail 없으면 첫 페이지 이미지
        let thumbnail = self.thumbnailURL ?? pages.first?.imageURL
        return .init(
            id: self.id,
            title: self.title,
            subtitle: self.subtitle,
            thumbnailURL: thumbnail,
            category: self.category,
            pageCount: self.pageCount,
            isSponsored: self.isSponsored,
            sponsorName: self.sponsorName,
            sponsorLink: self.sponsorLink,
            isPremium: self.isPremium,
            pages: pages,
            createdAt: self.createdAt
        )
    }
}

extension CardNewsPage {
    func toDTO() -> CardNewsPageDTO {
        .init(
            pageIndex: self.pageIndex,
            imageURL: self.imageURL,
            title: self.title,
            body: self.body,
            bgColor: self.bgColor
        )
    }
}
