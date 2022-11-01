import Logging
import SotoDynamoDB

public enum RepositoryFactory {
    public typealias UserRepoParameters = (
        db: DynamoDB,
        tableName: String,
        eventLoop: EventLoop,
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
}
