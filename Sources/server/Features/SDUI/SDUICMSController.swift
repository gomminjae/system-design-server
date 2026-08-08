import Fluent
import Foundation
import Vapor

struct SDUICMSController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let cms = routes.grouped("admin", "sdui")
        cms.get(use: self.dashboard)
        cms.get("projects", use: self.listProjects)
        cms.put("projects", ":projectID", use: self.upsertProject)
        cms.get("projects", ":projectID", "screens", use: self.listScreens)
        cms.get("projects", ":projectID", "screens", ":screenID", use: self.getScreenDraft)
        cms.get("projects", ":projectID", "screens", ":screenID", "revisions", use: self.listScreenRevisions)
        cms.put("projects", ":projectID", "screens", ":screenID", "draft", use: self.saveScreenDraft)
        cms.post("projects", ":projectID", "screens", ":screenID", "validate", use: self.validateScreen)
        cms.post("projects", ":projectID", "screens", ":screenID", "publish", use: self.publishScreen)
        cms.post("projects", ":projectID", "screens", ":screenID", "rollback", use: self.rollbackScreen)
        cms.get("projects", ":projectID", "theme", use: self.getThemeDraft)
        cms.get("projects", ":projectID", "theme", "revisions", use: self.listThemeRevisions)
        cms.put("projects", ":projectID", "theme", "draft", use: self.saveThemeDraft)
        cms.post("projects", ":projectID", "theme", "validate", use: self.validateTheme)
        cms.post("projects", ":projectID", "theme", "publish", use: self.publishTheme)
        cms.post("projects", ":projectID", "theme", "rollback", use: self.rollbackTheme)
    }

    @Sendable
    func dashboard(req: Request) async throws -> Response {
        var headers = HTTPHeaders()
        headers.contentType = .html
        return Response(status: .ok, headers: headers, body: .init(string: Self.dashboardHTML))
    }

    @Sendable
    func listProjects(req: Request) async throws -> APIResponse<[SDUICMSProjectResponse]> {
        let projects = try await SDUIProject.query(on: req.db).sort(\.$projectID).all()
        return APIResponse(projects.map { .init(id: $0.projectID, catalogVersion: $0.catalogVersion) })
    }

    @Sendable
    func upsertProject(req: Request) async throws -> APIResponse<SDUICMSProjectResponse> {
        let projectID = try projectID(from: req)
        guard isIdentifier(projectID) else { throw APIError.validation("프로젝트 ID 형식이 올바르지 않습니다.") }
        let body = try req.content.decode(SDUICMSProjectRequest.self)
        guard !body.catalogVersion.isEmpty else { throw APIError.validation("catalogVersion이 필요합니다.") }

        let project = try await project(projectID, on: req.db) ?? SDUIProject(projectID: projectID, catalogVersion: body.catalogVersion)
        project.catalogVersion = body.catalogVersion
        try await project.save(on: req.db)
        return APIResponse(.init(id: project.projectID, catalogVersion: project.catalogVersion))
    }

    @Sendable
    func listScreens(req: Request) async throws -> APIResponse<[String]> {
        let projectID = try projectID(from: req)
        try await requireProject(projectID, on: req.db)
        let screens = try await SDUIScreenRevision.query(on: req.db)
            .filter(\.$projectID == projectID)
            .sort(\.$screenID)
            .all()
        return APIResponse(Array(Set(screens.map { $0.screenID })).sorted())
    }

    @Sendable
    func getScreenDraft(req: Request) async throws -> SDUIStoredDocument {
        let projectID = try projectID(from: req)
        let screenID = try screenID(from: req)
        try await requireProject(projectID, on: req.db)
        guard let revision = try await latestScreenRevision(projectID: projectID, screenID: screenID, statuses: [.draft, .published], on: req.db) else {
            throw APIError.notFound("화면 초안이 없습니다.")
        }
        return try decodeScreen(revision)
    }

    @Sendable
    func listScreenRevisions(req: Request) async throws -> APIResponse<[SDUICMSRevisionSummary]> {
        let projectID = try projectID(from: req)
        let screenID = try screenID(from: req)
        try await requireProject(projectID, on: req.db)
        let revisions = try await SDUIScreenRevision.query(on: req.db)
            .filter(\.$projectID == projectID)
            .filter(\.$screenID == screenID)
            .sort(\.$revision, .descending)
            .all()
        return APIResponse(revisions.map { .init(revision: $0.revision, status: $0.status, createdAt: $0.createdAt) })
    }

    @Sendable
    func saveScreenDraft(req: Request) async throws -> APIResponse<SDUICMSRevisionSummary> {
        let projectID = try projectID(from: req)
        let screenID = try screenID(from: req)
        guard isIdentifier(screenID) else { throw APIError.validation("screen ID 형식이 올바르지 않습니다.") }
        let project = try await requireProject(projectID, on: req.db)
        let body = try req.content.decode(SDUICMSScreenDraftRequest.self)
        let catalogVersion = body.catalogVersion ?? project.catalogVersion
        guard catalogVersion == project.catalogVersion else { throw APIError.validation("프로젝트 catalogVersion과 일치하지 않습니다.") }
        let document = SDUIStoredDocument(
            protocolVersion: 1,
            catalogVersion: catalogVersion,
            theme: .init(id: projectID, revision: (await latestPublishedThemeRevision(on: req.db, projectID: projectID)) ?? 1),
            screen: body.screen
        )
        try validate(document)
        let nextRevision = (try await SDUIScreenRevision.query(on: req.db)
            .filter(\.$projectID == projectID)
            .filter(\.$screenID == screenID)
            .max(\.$revision) ?? 0) + 1
        try await SDUIScreenRevision.query(on: req.db)
            .filter(\.$projectID == projectID)
            .filter(\.$screenID == screenID)
            .filter(\.$status == SDUIRevisionStatus.draft.rawValue)
            .set(\.$status, to: SDUIRevisionStatus.archived.rawValue)
            .update()
        let revision = SDUIScreenRevision(
            projectID: projectID,
            screenID: screenID,
            revision: nextRevision,
            status: .draft,
            documentJSON: try SDUIJSON.encode(document)
        )
        try await revision.save(on: req.db)
        return APIResponse(.init(revision: revision.revision, status: revision.status, createdAt: revision.createdAt))
    }

    @Sendable
    func validateScreen(req: Request) async throws -> APIResponse<SDUICMSValidateResponse> {
        let projectID = try projectID(from: req)
        let screenID = try screenID(from: req)
        try await requireProject(projectID, on: req.db)
        guard let revision = try await latestScreenRevision(projectID: projectID, screenID: screenID, statuses: [.draft, .published], on: req.db) else {
            throw APIError.notFound("검증할 화면이 없습니다.")
        }
        do {
            try validate(try decodeScreen(revision))
            return APIResponse(.init(valid: true, issues: []))
        } catch let error as SDUIValidationError {
            return APIResponse(.init(valid: false, issues: error.issues))
        }
    }

    @Sendable
    func publishScreen(req: Request) async throws -> APIResponse<SDUICMSRevisionSummary> {
        let projectID = try projectID(from: req)
        let screenID = try screenID(from: req)
        let body = try req.content.decode(SDUICMSPublishRequest.self)
        let revision = try await screenRevision(projectID: projectID, screenID: screenID, revision: body.revision, on: req.db)
        try validate(try decodeScreen(revision))
        try await req.db.transaction { database in
            try await SDUIScreenRevision.query(on: database)
                .filter(\.$projectID == projectID)
                .filter(\.$screenID == screenID)
                .filter(\.$status == SDUIRevisionStatus.published.rawValue)
                .set(\.$status, to: SDUIRevisionStatus.archived.rawValue)
                .update()
            revision.status = SDUIRevisionStatus.published.rawValue
            try await revision.save(on: database)
        }
        return APIResponse(.init(revision: revision.revision, status: revision.status, createdAt: revision.createdAt))
    }

    @Sendable
    func rollbackScreen(req: Request) async throws -> APIResponse<SDUICMSRevisionSummary> {
        let projectID = try projectID(from: req)
        let screenID = try screenID(from: req)
        let body = try req.content.decode(SDUICMSPublishRequest.self)
        guard let target = body.revision else { throw APIError.validation("rollback할 revision이 필요합니다.") }
        let revision = try await screenRevision(projectID: projectID, screenID: screenID, revision: target, on: req.db)
        try validate(try decodeScreen(revision))
        try await req.db.transaction { database in
            try await SDUIScreenRevision.query(on: database)
                .filter(\.$projectID == projectID)
                .filter(\.$screenID == screenID)
                .filter(\.$status == SDUIRevisionStatus.published.rawValue)
                .set(\.$status, to: SDUIRevisionStatus.archived.rawValue)
                .update()
            revision.status = SDUIRevisionStatus.published.rawValue
            try await revision.save(on: database)
        }
        return APIResponse(.init(revision: revision.revision, status: revision.status, createdAt: revision.createdAt))
    }

    @Sendable
    func getThemeDraft(req: Request) async throws -> SDUIThemeDocument {
        let projectID = try projectID(from: req)
        try await requireProject(projectID, on: req.db)
        guard let revision = try await latestThemeRevision(projectID: projectID, statuses: [.draft, .published], on: req.db) else {
            throw APIError.notFound("테마 초안이 없습니다.")
        }
        return try SDUIJSON.decode(SDUIThemeDocument.self, from: revision.documentJSON)
    }

    @Sendable
    func listThemeRevisions(req: Request) async throws -> APIResponse<[SDUICMSRevisionSummary]> {
        let projectID = try projectID(from: req)
        try await requireProject(projectID, on: req.db)
        let revisions = try await SDUIThemeRevision.query(on: req.db)
            .filter(\.$projectID == projectID)
            .sort(\.$revision, .descending)
            .all()
        return APIResponse(revisions.map { .init(revision: $0.revision, status: $0.status, createdAt: $0.createdAt) })
    }

    @Sendable
    func saveThemeDraft(req: Request) async throws -> APIResponse<SDUICMSRevisionSummary> {
        let projectID = try projectID(from: req)
        try await requireProject(projectID, on: req.db)
        let body = try req.content.decode(SDUICMSThemeDraftRequest.self)
        try validate(body.theme)
        let nextRevision = (try await SDUIThemeRevision.query(on: req.db)
            .filter(\.$projectID == projectID)
            .max(\.$revision) ?? 0) + 1
        try await SDUIThemeRevision.query(on: req.db)
            .filter(\.$projectID == projectID)
            .filter(\.$status == SDUIRevisionStatus.draft.rawValue)
            .set(\.$status, to: SDUIRevisionStatus.archived.rawValue)
            .update()
        let revision = SDUIThemeRevision(projectID: projectID, revision: nextRevision, status: .draft, documentJSON: try SDUIJSON.encode(body.theme))
        try await revision.save(on: req.db)
        return APIResponse(.init(revision: revision.revision, status: revision.status, createdAt: revision.createdAt))
    }

    @Sendable
    func validateTheme(req: Request) async throws -> APIResponse<SDUICMSValidateResponse> {
        let projectID = try projectID(from: req)
        try await requireProject(projectID, on: req.db)
        guard let revision = try await latestThemeRevision(projectID: projectID, statuses: [.draft, .published], on: req.db) else {
            throw APIError.notFound("검증할 테마가 없습니다.")
        }
        do {
            try validate(try SDUIJSON.decode(SDUIThemeDocument.self, from: revision.documentJSON))
            return APIResponse(.init(valid: true, issues: []))
        } catch let error as SDUIValidationError {
            return APIResponse(.init(valid: false, issues: error.issues))
        }
    }

    @Sendable
    func publishTheme(req: Request) async throws -> APIResponse<SDUICMSRevisionSummary> {
        try await changeThemeStatus(req: req, requestedStatus: .published)
    }

    @Sendable
    func rollbackTheme(req: Request) async throws -> APIResponse<SDUICMSRevisionSummary> {
        try await changeThemeStatus(req: req, requestedStatus: .published)
    }

    private func changeThemeStatus(req: Request, requestedStatus: SDUIRevisionStatus) async throws -> APIResponse<SDUICMSRevisionSummary> {
        let projectID = try projectID(from: req)
        try await requireProject(projectID, on: req.db)
        let body = try req.content.decode(SDUICMSPublishRequest.self)
        let latestDraftRevision = try await latestThemeRevision(projectID: projectID, statuses: [.draft], on: req.db)?.revision
        let revisionNumber = body.revision ?? latestDraftRevision
        guard let revisionNumber else { throw APIError.validation("발행할 theme revision이 없습니다.") }
        guard let revision = try await SDUIThemeRevision.query(on: req.db)
            .filter(\.$projectID == projectID)
            .filter(\.$revision == revisionNumber)
            .first() else { throw APIError.notFound("테마 revision을 찾을 수 없습니다.") }
        try validate(try SDUIJSON.decode(SDUIThemeDocument.self, from: revision.documentJSON))
        try await req.db.transaction { database in
            try await SDUIThemeRevision.query(on: database)
                .filter(\.$projectID == projectID)
                .filter(\.$status == SDUIRevisionStatus.published.rawValue)
                .set(\.$status, to: SDUIRevisionStatus.archived.rawValue)
                .update()
            revision.status = requestedStatus.rawValue
            try await revision.save(on: database)
        }
        return APIResponse(.init(revision: revision.revision, status: revision.status, createdAt: revision.createdAt))
    }

    private func projectID(from req: Request) throws -> String {
        guard let value = req.parameters.get("projectID") else { throw APIError.validation("projectID가 필요합니다.") }
        return value
    }

    private func screenID(from req: Request) throws -> String {
        guard let value = req.parameters.get("screenID") else { throw APIError.validation("screenID가 필요합니다.") }
        return value
    }

    private func project(_ id: String, on database: any Database) async throws -> SDUIProject? {
        try await SDUIProject.query(on: database).filter(\.$projectID == id).first()
    }

    private func requireProject(_ id: String, on database: any Database) async throws -> SDUIProject {
        guard let project = try await project(id, on: database) else { throw APIError.notFound("SDUI 프로젝트를 찾을 수 없습니다.") }
        return project
    }

    private func latestScreenRevision(projectID: String, screenID: String, statuses: [SDUIRevisionStatus], on database: any Database) async throws -> SDUIScreenRevision? {
        try await SDUIScreenRevision.query(on: database)
            .filter(\.$projectID == projectID)
            .filter(\.$screenID == screenID)
            .group(.or) { group in
                for status in statuses { group.filter(\.$status == status.rawValue) }
            }
            .sort(\.$revision, .descending)
            .first()
    }

    private func latestThemeRevision(projectID: String, statuses: [SDUIRevisionStatus], on database: any Database) async throws -> SDUIThemeRevision? {
        try await SDUIThemeRevision.query(on: database)
            .filter(\.$projectID == projectID)
            .group(.or) { group in
                for status in statuses { group.filter(\.$status == status.rawValue) }
            }
            .sort(\.$revision, .descending)
            .first()
    }

    private func latestPublishedThemeRevision(on database: any Database, projectID: String) async -> Int? {
        try? await SDUIThemeRevision.query(on: database)
            .filter(\.$projectID == projectID)
            .filter(\.$status == SDUIRevisionStatus.published.rawValue)
            .sort(\.$revision, .descending)
            .first()?.revision
    }

    private func screenRevision(projectID: String, screenID: String, revision number: Int?, on database: any Database) async throws -> SDUIScreenRevision {
        let query = SDUIScreenRevision.query(on: database)
            .filter(\.$projectID == projectID)
            .filter(\.$screenID == screenID)
        if let number {
            guard let revision = try await query.filter(\.$revision == number).first() else { throw APIError.notFound("화면 revision을 찾을 수 없습니다.") }
            return revision
        }
        guard let revision = try await query.filter(\.$status == SDUIRevisionStatus.draft.rawValue).sort(\.$revision, .descending).first() else {
            throw APIError.notFound("발행할 화면 초안이 없습니다.")
        }
        return revision
    }

    private func decodeScreen(_ revision: SDUIScreenRevision) throws -> SDUIStoredDocument {
        do { return try SDUIJSON.decode(SDUIStoredDocument.self, from: revision.documentJSON) }
        catch { throw APIError.internalServerError("저장된 화면 JSON을 읽을 수 없습니다.") }
    }

    private func validate(_ document: SDUIStoredDocument) throws {
        try SDUIScreenValidator().validate(.init(protocolVersion: document.protocolVersion, catalogVersion: document.catalogVersion, theme: document.theme, screen: document.screen))
    }

    private func validate(_ theme: SDUIThemeDocument) throws {
        try SDUIThemeValidator().validate(theme)
    }

    private func isIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 80 && value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" || $0 == "-" }
    }

    private static let dashboardHTML = #"""
    <!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SDUI Studio</title>
    <style>
    :root{font-family:Inter,system-ui,-apple-system,sans-serif;color:#e9e7ff;background:#12101b}*{box-sizing:border-box}body{margin:0}header{height:72px;padding:0 28px;display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid #2b263d;background:#181526}h1{font-size:20px;margin:0}main{display:grid;grid-template-columns:240px minmax(320px,1fr) 340px;min-height:calc(100vh - 72px)}aside,.inspector{padding:22px;border-right:1px solid #2b263d;background:#151221}.inspector{border-right:0;border-left:1px solid #2b263d}button,select,input,textarea{font:inherit;color:inherit;background:#201b32;border:1px solid #403658;border-radius:8px;padding:9px}button{cursor:pointer;background:#7057e8;border-color:#806ae9;font-weight:600}button.secondary{background:#211c31}.wide{width:100%;margin-bottom:10px}.stage{padding:28px;background:radial-gradient(circle at 50% 15%,#292044 0,#12101b 55%);display:flex;justify-content:center}.phone{width:min(390px,100%);min-height:620px;background:#fff;color:#252230;border-radius:30px;padding:24px;box-shadow:0 20px 80px #05030c;overflow:auto}.node{border:1px dashed #b6a9e9;padding:12px;margin:8px 0;border-radius:8px}.node.selected{outline:3px solid #7057e8}.node.layout{min-height:55px;background:#f7f5ff}.node img{max-width:100%}.node button{color:#fff}.label{font-size:12px;color:#9e95b7;display:block;margin:14px 0 5px}.row{display:flex;gap:8px}.row>*{flex:1}.muted{color:#aaa0bf;font-size:13px}.status{padding:4px 8px;border-radius:20px;background:#2a2341;color:#cabfff;font-size:12px}.list button{display:block;text-align:left;width:100%;margin:6px 0;background:#211c31}.list button.active{background:#7057e8}.toolbar{display:flex;gap:8px;align-items:center}.danger{background:#6e3458}pre{white-space:pre-wrap;font-size:12px;color:#cfc8e8;background:#0e0c15;padding:10px;border-radius:8px;max-height:180px;overflow:auto}@media(max-width:900px){main{grid-template-columns:190px 1fr}.inspector{grid-column:1/-1;border-left:0;border-top:1px solid #2b263d}.phone{min-height:450px}}
    </style></head><body><header><h1>SDUI Studio <span class="status">CMS</span></h1><div class="toolbar"><select id="project"></select><button onclick="newProject()" class="secondary">프로젝트 추가</button><button onclick="save()">저장</button><button onclick="publish()">발행</button></div></header><main><aside><div class="muted">화면</div><div id="screens" class="list"></div><button class="wide secondary" onclick="addScreen()">+ 화면 추가</button><hr><div class="muted">컴포넌트 추가</div><div id="components"></div></aside><section class="stage"><div class="phone" id="preview"></div></section><section class="inspector"><div class="muted">선택한 컴포넌트</div><div id="empty">화면에서 컴포넌트를 선택하세요.</div><div id="form" hidden></div><hr><div class="muted">검증 로그</div><pre id="log">준비됨</pre></section></main>
    <script>
    const types={vStack:'세로 스택',hStack:'가로 스택',text:'텍스트',image:'이미지',button:'버튼'};let project='demo',screen='home',doc,selected;
    const initial={id:'home',revision:1,fallback:{type:'native',target:'home'},root:{id:'root',type:'vStack',props:{gap:'x4',paddingX:'globalGutter',alignment:'stretch'},children:[{id:'title',type:'text',props:{text:'새 화면 제목',textStyle:'heading',color:'neutral'}},{id:'body',type:'text',props:{text:'CMS에서 조합한 SDUI 화면입니다.',textStyle:'body',color:'neutralMuted',maxLines:3}},{id:'cta',type:'button',props:{label:'시작하기',tone:'brand',variant:'solid',size:'large'},action:{type:'navigate',target:'about'}}]}};
    async function api(url,opt={}){let r=await fetch(url,{headers:{'content-type':'application/json',...(opt.headers||{})},...opt});let j=await r.json().catch(()=>({}));if(!r.ok)throw Error(j.error?.message||j.reason||r.status);return j.data??j}
    async function boot(){try{let ps=await api('/admin/sdui/projects');if(!ps.length){await api('/admin/sdui/projects/demo',{method:'PUT',body:JSON.stringify({catalogVersion:'seed-mobile-v1'})});ps=await api('/admin/sdui/projects')}project=ps[0].id;document.getElementById('project').innerHTML=ps.map(p=>`<option value="${p.id}">${p.id}</option>`).join('');document.getElementById('project').value=project;document.getElementById('project').onchange=()=>{project=document.getElementById('project').value;loadScreens()};await loadScreens()}catch(e){log(e.message)}}
    async function loadScreens(){let ss=await api(`/admin/sdui/projects/${project}/screens`);if(!ss.length){screen='home';doc={screen:structuredClone(initial)};renderScreens();render()}else{screen=ss[0];renderScreens();await load()}}
    async function load(){try{doc=await api(`/admin/sdui/projects/${project}/screens/${screen}`);render()}catch(e){doc={screen:structuredClone(initial)};render();log('새 화면 초안입니다. '+e.message)}}
    function renderScreens(){document.getElementById('screens').innerHTML=(screen?[screen]:[]).map(s=>`<button class="active" onclick="screen='${s}';load()">${s}</button>`).join('')}
    function addScreen(){let id=prompt('화면 ID','new-screen');if(!id)return;screen=id;doc={screen:{...structuredClone(initial),id,fallback:{type:'native',target:id}}};renderScreens();render()}
    async function newProject(){let id=prompt('프로젝트 ID','brand-app');if(!id)return;try{await api(`/admin/sdui/projects/${id}`,{method:'PUT',body:JSON.stringify({catalogVersion:'seed-mobile-v1'})});await boot();document.getElementById('project').value=id;project=id;await loadScreens()}catch(e){log(e.message)}}
    function add(type){let n={id:type+'-'+Date.now(),type,props:{}};if(type==='vStack'||type==='hStack')n={...n,props:{gap:'x3',alignment:'stretch'},children:[]};if(type==='text')n.props={text:'새 텍스트',textStyle:'body',color:'neutral'};if(type==='image')n.props={imageURL:'https://placehold.co/640x360/png',alt:'이미지',aspectRatio:1.78};if(type==='button')n={...n,props:{label:'버튼',tone:'brand',variant:'solid',size:'medium'},action:{type:'navigate',target:'home'}};doc.screen.root.children??=[];doc.screen.root.children.push(n);selected=n.id;render()}
    document.getElementById('components').innerHTML=Object.entries(types).map(([k,v])=>`<button class="wide secondary" onclick="add('${k}')">+ ${v}</button>`).join('');
    function walk(n){if(n.id===selected)return n;for(let c of n.children||[]){let x=walk(c);if(x)return x}}
    function render(){let p=document.getElementById('preview');p.innerHTML='';p.appendChild(view(doc.screen.root));let n=walk(doc.screen.root);document.getElementById('empty').hidden=!!n;document.getElementById('form').hidden=!n;if(n)inspect(n)}
    function view(n){let e=document.createElement(n.type==='text'?'p':n.type==='image'?'img':n.type==='button'?'button':'div');e.className='node '+((n.type==='vStack'||n.type==='hStack')?'layout ':'')+(n.id===selected?'selected':'');e.onclick=x=>{x.stopPropagation();selected=n.id;render()};let p=n.props||{};if(n.type==='text')e.textContent=p.text||'';if(n.type==='image'){e.src=p.imageURL;e.alt=p.alt||''}if(n.type==='button'){e.textContent=p.label||'버튼';e.onclick=x=>{x.stopPropagation();selected=n.id;render()}}for(let c of n.children||[])e.appendChild(view(c));return e}
    function inspect(n){let f=document.getElementById('form');let keys=n.type==='text'?['text','textStyle','color','maxLines']:n.type==='button'?['label','tone','variant','size']:n.type==='image'?['imageURL','alt','aspectRatio']:['gap','paddingX','alignment'];f.innerHTML=`<div class="status">${types[n.type]} · ${n.id}</div>`+keys.map(k=>`<label class="label">${k}</label><input data-key="${k}" value="${n.props?.[k]??''}" />`).join('')+`<button class="wide danger" onclick="removeSelected()">삭제</button>`;f.querySelectorAll('input').forEach(i=>i.oninput=()=>{n.props??={};n.props[i.dataset.key]=i.value||undefined;render()})}
    function removeSelected(){if(!selected||selected==='root')return;function rm(n){if(!n.children)return false;let i=n.children.findIndex(c=>c.id===selected);if(i>=0){n.children.splice(i,1);return true}return n.children.some(rm)}rm(doc.screen.root);selected=null;render()}
    async function save(){try{let r=await api(`/admin/sdui/projects/${project}/screens/${screen}/draft`,{method:'PUT',body:JSON.stringify({screen:doc.screen})});log('저장 완료 revision '+r.revision)}catch(e){log(e.message)}}async function publish(){try{await save();let r=await api(`/admin/sdui/projects/${project}/screens/${screen}/publish`,{method:'POST',body:JSON.stringify({})});log('발행 완료 revision '+r.revision)}catch(e){log(e.message)}}function log(x){document.getElementById('log').textContent=x}boot();
    </script></body></html>
    """#.replacingOccurrences(of: "\\\"", with: "\"")
}
