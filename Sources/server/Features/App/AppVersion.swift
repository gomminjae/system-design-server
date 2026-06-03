import Fluent
import Vapor

final class AppVersion: Model, @unchecked Sendable {
    static let schema = "app_versions"

    @ID(key: .id) var id: UUID?
    @Field(key: "platform") var platform: String
    @Field(key: "min_version") var minVersion: String
    @Field(key: "latest_version") var latestVersion: String
    @Field(key: "release_notes") var releaseNotes: [String]
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?

    init() {}

    init(platform: String, minVersion: String, latestVersion: String, releaseNotes: [String] = []) {
        self.platform = platform
        self.minVersion = minVersion
        self.latestVersion = latestVersion
        self.releaseNotes = releaseNotes
    }
}
