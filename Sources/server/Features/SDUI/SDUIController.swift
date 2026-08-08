import Fluent
import Vapor

struct SDUIController: RouteCollection {
    private static let catalogHeader = HTTPHeaders.Name("X-SDUI-Catalog-Version")

    func boot(routes: any RoutesBuilder) throws {
        let projects = routes.grouped("v1", "projects")
        projects.get(":projectID", "theme", use: self.theme)
        projects.get(":projectID", "screens", ":screenID", use: self.screen)
    }

    /// GET /v1/projects/:projectID/theme
    @Sendable
    func theme(req: Request) async throws -> APIResponse<SDUIThemeDocument> {
        if let projectID = req.parameters.get("projectID"),
           let storedProject = try await SDUIProject.query(on: req.db)
            .filter(\.$projectID == projectID)
            .first(),
           let revision = try await SDUIThemeRevision.query(on: req.db)
            .filter(\.$projectID == projectID)
            .filter(\.$status == SDUIRevisionStatus.published.rawValue)
            .sort(\.$revision, .descending)
            .first() {
            guard storedProject.catalogVersion.isEmpty == false else {
                throw APIError.internalServerError("프로젝트 catalogVersion이 올바르지 않습니다.")
            }
            do {
                let theme = try SDUIJSON.decode(SDUIThemeDocument.self, from: revision.documentJSON)
                try SDUIThemeValidator().validate(theme)
                return APIResponse(theme)
            } catch let error as SDUIValidationError {
                req.logger.error("Invalid published SDUI theme: \(error.issues.joined(separator: "; "))")
                throw APIError.internalServerError("배포된 테마가 올바르지 않습니다.")
            } catch {
                throw APIError.internalServerError("배포된 테마를 읽을 수 없습니다.")
            }
        }
        let project = try findProject(req)
        do {
            try SDUIThemeValidator().validate(project.theme)
        } catch let error as SDUIValidationError {
            req.logger.error("Invalid published SDUI theme: \(error.issues.joined(separator: "; "))")
            throw APIError.internalServerError("배포된 테마가 올바르지 않습니다.")
        }
        return APIResponse(project.theme)
    }

    /// GET /v1/projects/:projectID/screens/:screenID
    @Sendable
    func screen(req: Request) async throws -> APIResponse<SDUIScreenDocument> {
        if let projectID = req.parameters.get("projectID"),
           let storedProject = try await SDUIProject.query(on: req.db)
            .filter(\.$projectID == projectID)
            .first() {
            if let clientCatalog = req.headers.first(name: Self.catalogHeader),
               clientCatalog != storedProject.catalogVersion {
                throw APIError.preconditionFailed(
                    code: "unsupported_sdui_catalog",
                    message: "클라이언트가 프로젝트의 SDUI 컴포넌트 카탈로그를 지원하지 않습니다."
                )
            }
            guard let screenID = req.parameters.get("screenID"),
                  let revision = try await SDUIScreenRevision.query(on: req.db)
                    .filter(\.$projectID == projectID)
                    .filter(\.$screenID == screenID)
                    .filter(\.$status == SDUIRevisionStatus.published.rawValue)
                    .sort(\.$revision, .descending)
                    .first() else {
                if SDUIProjectRegistry.project(id: projectID) == nil {
                    throw APIError.notFound("발행된 화면을 찾을 수 없습니다.")
                }
                // A project created in CMS may still use its code-defined fallback until its first publish.
                return try await screenFromRegistry(req: req)
            }
            do {
                let document = try SDUIJSON.decode(SDUIStoredDocument.self, from: revision.documentJSON)
                let response = SDUIScreenDocument(
                    protocolVersion: document.protocolVersion,
                    catalogVersion: document.catalogVersion,
                    theme: document.theme,
                    screen: document.screen
                )
                try SDUIScreenValidator().validate(response)
                return APIResponse(response)
            } catch let error as SDUIValidationError {
                req.logger.error("Invalid published SDUI screen: \(error.issues.joined(separator: "; "))")
                throw APIError.internalServerError("배포된 화면이 올바르지 않습니다.")
            } catch {
                throw APIError.internalServerError("배포된 화면을 읽을 수 없습니다.")
            }
        }
        return try await screenFromRegistry(req: req)
    }

    private func screenFromRegistry(req: Request) async throws -> APIResponse<SDUIScreenDocument> {
        let project = try findProject(req)
        if let clientCatalog = req.headers.first(name: Self.catalogHeader),
           clientCatalog != project.catalogVersion {
            throw APIError.preconditionFailed(
                code: "unsupported_sdui_catalog",
                message: "클라이언트가 프로젝트의 SDUI 컴포넌트 카탈로그를 지원하지 않습니다."
            )
        }

        guard let screenID = req.parameters.get("screenID"),
              let screen = project.screens[screenID] else {
            throw APIError.notFound("화면을 찾을 수 없습니다.")
        }

        let document = SDUIScreenDocument(
            protocolVersion: 1,
            catalogVersion: project.catalogVersion,
            theme: .init(id: project.theme.id, revision: project.theme.revision),
            screen: screen
        )
        do {
            try SDUIScreenValidator().validate(document)
        } catch let error as SDUIValidationError {
            req.logger.error("Invalid published SDUI screen: \(error.issues.joined(separator: "; "))")
            throw APIError.internalServerError("배포된 화면이 올바르지 않습니다.")
        }
        return APIResponse(document)
    }

    private func findProject(_ req: Request) throws -> SDUIProjectDefinition {
        guard let projectID = req.parameters.get("projectID"),
              let project = SDUIProjectRegistry.project(id: projectID) else {
            throw APIError.notFound("SDUI 프로젝트를 찾을 수 없습니다.")
        }
        return project
    }
}
