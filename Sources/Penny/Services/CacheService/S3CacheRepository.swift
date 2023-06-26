import SotoS3
import Foundation

struct S3CacheRepository {

    let s3: S3
    let logger: Logger
    let bucket = "penny-caches"
    let key = "caches.json"

    let decoder = JSONDecoder()
    let encoder = JSONEncoder()

    init(awsClient: AWSClient, logger: Logger) {
        self.s3 = S3(client: awsClient, region: .euwest1)
        self.logger = logger
    }

    func get() async throws -> CachesStorage {
        let request = S3.GetObjectRequest(bucket: bucket, key: key)
        let response = try await s3.getObject(request, logger: logger)

        if let buffer = response.body?.asByteBuffer(), buffer.readableBytes != 0 {
            do {
                return try decoder.decode(CachesStorage.self, from: buffer)
            } catch {
                let body = response.body?.asString() ?? "nil"
                logger.error("Cannot find any data in the bucket", metadata: [
                    "response-body": .string(body),
                    "error": "\(error)"
                ])
                return CachesStorage()
            }
        } else {
            let body = response.body?.asString() ?? "nil"
            logger.error("Cannot find any data in the bucket", metadata: [
                "response-body": .string(body)
            ])
            return CachesStorage()
        }
    }

    func save(storage: CachesStorage) async throws {
        let data = try encoder.encode(storage)
        let putObjectRequest = S3.PutObjectRequest(
            acl: .private,
            body: .data(data),
            bucket: bucket,
            key: key
        )
        _ = try await s3.putObject(putObjectRequest)
    }

    func delete() async throws {
        let deleteObjectRequest = S3.DeleteObjectRequest(bucket: bucket, key: key)
        _ = try await s3.deleteObject(deleteObjectRequest)
    }
}
