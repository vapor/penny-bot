import SotoDynamoDB

public enum RepositoryFactory {
    public typealias UserRepoParameters = (
        db: DynamoDB,
        tableName: String,
        eventLoop: any EventLoop,
        logger: Logger
    )
    
    public static var makeUserRepository: (UserRepoParameters) -> any UserRepository = {
        DynamoUserRepository(
            db: $0.db,
            tableName: $0.tableName,
            eventLoop: $0.eventLoop,
            logger: $0.logger
        )
    }
    
    public static var makeAutoPingsRepository: (Logger) -> any AutoPingsRepository = {
        S3AutoPingsRepository(logger: $0)
    }
}
