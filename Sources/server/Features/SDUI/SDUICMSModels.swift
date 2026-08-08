import Fluent
import Foundation
import Vapor

enum SDUIRevisionStatus: String, Codable, Sendable {
    case draft
    case published
    case archived
}

final class SDUIProject: Model, @unchecked Sendable {
    static let schema = "sdui_projects"

    @ID(key: .id) var id: UUID?
    @Field(key: "project_id") var projectID: String
    @Field(key: "catalog_version") var catalogVersion: String
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?

    init() {}

    init(projectID: String, catalogVersion: String) {
        self.projectID = projectID
        self.catalogVersion = catalogVersion
    }
}

final class SDUIScreenRevision: Model, @unchecked Sendable {
    static let schema = "sdui_screen_revisions"

    @ID(key: .id) var id: UUID?
    @Field(key: "project_id") var projectID: String
    @Field(key: "screen_id") var screenID: String
    @Field(key: "revision") var revision: Int
    @Field(key: "status") var status: String
    @Field(key: "document_json") var documentJSON: String
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?

    init() {}

    init(projectID: String, screenID: String, revision: Int, status: SDUIRevisionStatus, documentJSON: String) {
        self.projectID = projectID
        self.screenID = screenID
        self.revision = revision
        self.status = status.rawValue
        self.documentJSON = documentJSON
    }

    var revisionStatus: SDUIRevisionStatus? { SDUIRevisionStatus(rawValue: status) }
}

final class SDUIThemeRevision: Model, @unchecked Sendable {
    static let schema = "sdui_theme_revisions"

    @ID(key: .id) var id: UUID?
    @Field(key: "project_id") var projectID: String
    @Field(key: "revision") var revision: Int
    @Field(key: "status") var status: String
    @Field(key: "document_json") var documentJSON: String
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?

    init() {}

    init(projectID: String, revision: Int, status: SDUIRevisionStatus, documentJSON: String) {
        self.projectID = projectID
        self.revision = revision
        self.status = status.rawValue
        self.documentJSON = documentJSON
    }

    var revisionStatus: SDUIRevisionStatus? { SDUIRevisionStatus(rawValue: status) }
}

struct SDUICMSProjectRequest: Content, Sendable {
    let catalogVersion: String
}

struct SDUICMSScreenDraftRequest: Content, Sendable {
    let catalogVersion: String?
    let screen: SDUIScreen
}

struct SDUICMSPublishRequest: Content, Sendable {
    let revision: Int?
}

struct SDUICMSThemeDraftRequest: Content, Sendable {
    let theme: SDUIThemeDocument
}

struct SDUICMSRevisionSummary: Content, Sendable {
    let revision: Int
    let status: String
    let createdAt: Date?
}

struct SDUICMSProjectResponse: Content, Sendable {
    let id: String
    let catalogVersion: String
}

struct SDUICMSValidateResponse: Content, Sendable {
    let valid: Bool
    let issues: [String]
}

struct SDUIStoredDocument: Content, Sendable {
    let protocolVersion: Int
    let catalogVersion: String
    let theme: SDUIThemeReference
    let screen: SDUIScreen
}

enum SDUIJSON {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    static let decoder = JSONDecoder()

    static func encode<T: Encodable>(_ value: T) throws -> String {
        String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    static func decode<T: Decodable>(_ type: T.Type, from value: String) throws -> T {
        try decoder.decode(type, from: Data(value.utf8))
    }
}

struct CreateSDUICMS: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(SDUIProject.schema)
            .id()
            .field("project_id", .string, .required)
            .field("catalog_version", .string, .required)
            .field("updated_at", .datetime)
            .unique(on: "project_id")
            .create()

        try await database.schema(SDUIScreenRevision.schema)
            .id()
            .field("project_id", .string, .required)
            .field("screen_id", .string, .required)
            .field("revision", .int, .required)
            .field("status", .string, .required)
            .field("document_json", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "project_id", "screen_id", "revision")
            .create()

        try await database.schema(SDUIThemeRevision.schema)
            .id()
            .field("project_id", .string, .required)
            .field("revision", .int, .required)
            .field("status", .string, .required)
            .field("document_json", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "project_id", "revision")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(SDUIThemeRevision.schema).delete()
        try await database.schema(SDUIScreenRevision.schema).delete()
        try await database.schema(SDUIProject.schema).delete()
    }
}
