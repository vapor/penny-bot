import Logging
import SotoDynamoDB

public enum RepositoryFactory {
    public typealias UserRepoParameters = (
        db: DynamoDB,
        tableName: String,
        logger: Logger
    )
    
    public static var makeUserRepository: (UserRepoParameters) -> any UserRepository = {
        DynamoUserRepository(
            db: $0.db,
            tableName: $0.tableName,
            logger: $0.logger
        )
    }
}
