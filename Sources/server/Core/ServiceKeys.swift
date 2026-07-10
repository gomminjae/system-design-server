import Vapor

/// Request에서 서비스 인스턴스를 꺼내는 편의 확장.
extension Request {
    var userRepository: any UserRepository { FluentUserRepository(db: self.db) }

    var authService: AuthService {
        AuthService(repository: userRepository, app: self.application)
    }
}
