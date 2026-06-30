import Vapor

/// DI 키: BundleStorage
struct BundleStorageKey: StorageKey {
    typealias Value = any BundleStorage
}

extension Application {
    var bundleStorage: any BundleStorage {
        get { self.storage[BundleStorageKey.self]! }
        set { self.storage[BundleStorageKey.self] = newValue }
    }
}

/// Request에서 서비스 인스턴스를 꺼내는 편의 확장.
extension Request {
    var bundleStorage: any BundleStorage { self.application.bundleStorage }

    var productRepository: any ProductRepository { FluentProductRepository(db: self.db) }

    var productService: ProductService { ProductService(repository: productRepository) }

    var categoryService: CategoryService { CategoryService(db: self.db) }

    var cardNewsRepository: any CardNewsRepository { FluentCardNewsRepository(db: self.db) }

    var cardNewsService: CardNewsService { CardNewsService(repository: cardNewsRepository) }

    var screenResolver: ScreenResolver {
        ScreenResolver(products: productRepository, categories: categoryService, cardNews: cardNewsRepository)
    }

    var bundleService: BundleService { BundleService(storage: bundleStorage) }

    var reviewService: ReviewService {
        ReviewService(repository: productRepository, bundleService: bundleService)
    }

    var userRepository: any UserRepository { FluentUserRepository(db: self.db) }

    var authService: AuthService {
        AuthService(repository: userRepository, app: self.application)
    }
}
