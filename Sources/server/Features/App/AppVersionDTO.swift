import Vapor

struct AppVersionResponse: Content {
    let minVersion: String
    let latestVersion: String
    let releaseNotes: [String]
}

struct AppVersionUpdateRequest: Content {
    let platform: String
    let minVersion: String
    let latestVersion: String
    let releaseNotes: [String]
}
