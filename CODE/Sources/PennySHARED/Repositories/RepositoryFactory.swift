import SotoDynamoDB

public enum RepositoryFactory {
    public typealias RepoParameters = (
        db: DynamoDB,
        tableName: String,
        eventLoop: any EventLoop,
        logger: Logger
    )
    
    public static var makeUserRepository: (RepoParameters) -> any UserRepository = {
        DynamoUserRepository(
            db: $0.db,
            tableName: $0.tableName,
            eventLoop: $0.eventLoop,
            logger: $0.logger
        )
    }
    
    public static var makeAutoPingsRepository: (RepoParameters) -> any AutoPingsRepository = {
        DynamoAutoPingsRepository(
            db: $0.db,
            tableName: $0.tableName,
            eventLoop: $0.eventLoop,
            logger: $0.logger
        )
    }
}
