import SotoS3
import Foundation

struct S3CachesRepository {

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

        let body = try await response.body.collect(upTo: 1 << 24) /// 16 MiB
        if body.readableBytes == 0 {
            logger.error("Cannot find any data in the bucket")
            return CachesStorage()
        }

        do {
            return try decoder.decode(CachesStorage.self, from: body)
        } catch {
            logger.error("Cannot find any data in the bucket", metadata: [
                "response-body": .string(String(buffer: body)),
                "error": "\(error)"
            ])
            return CachesStorage()
        }
    }

    func save(storage: CachesStorage) async throws {
        let data = try encoder.encode(storage)
        let putObjectRequest = S3.PutObjectRequest(
            acl: .private,
            body: .init(bytes: data),
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
