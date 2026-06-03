import Fluent
import Vapor

final class Screen: Model, @unchecked Sendable {
    static let schema = "screens"

    @ID(key: .id) var id: UUID?
    @Field(key: "screen_id") var screenId: String
    @Field(key: "title") var title: String
    @Field(key: "sections_json") var sectionsJSON: String
    @Field(key: "is_published") var isPublished: Bool
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?

    init() {}

    init(screenId: String, title: String, sectionsJSON: String, isPublished: Bool = false) {
        self.screenId = screenId
        self.title = title
        self.sectionsJSON = sectionsJSON
        self.isPublished = isPublished
    }
}
