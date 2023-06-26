import SotoS3
import Foundation
import Models
import Extensions

public struct S3FaqsRepository {

    let s3: S3
    let logger: Logger
    let bucket = "penny-faqs-lambda"
    let key = "faqs-repo.json"

    let decoder = JSONDecoder()
    let encoder = JSONEncoder()

    public init(awsClient: AWSClient, logger: Logger) {
        self.s3 = S3(client: awsClient, region: .euwest1)
        self.logger = logger
    }

    public func insert(name: String, value: String) async throws -> [String: String] {
        var all = try await self.getAll()
        if all[name] != value {
            all[name] = value
            try await self.save(items: all)
        }
        return all
    }

    public func remove(name: String) async throws -> [String: String] {
        var all = try await self.getAll()
        if all.removeValue(forKey: name) != nil {
            try await self.save(items: all)
        }
        return all
    }

    public func getAll() async throws -> [String: String] {
        let response: S3.GetObjectOutput

        do {
            let request = S3.GetObjectRequest(bucket: bucket, key: key)
            response = try await s3.getObject(request, logger: logger)
        } catch {
            logger.error("Cannot retrieve the file from the bucket. If this is the first time, manually create a file named '\(self.key)' in bucket '\(self.bucket)' and set its content to empty json ('{}'). This has not been automated to reduce the chance of data loss", metadata: ["error": "\(error)"])
            throw error
        }

        if let buffer = response.body?.asByteBuffer(), buffer.readableBytes != 0 {
            do {
                return try decoder.decode([String: String].self, from: buffer)
            } catch {
                let body = response.body?.asString() ?? "nil"
                logger.error("Cannot find any data in the bucket", metadata: [
                    "response-body": .string(body),
                    "error": "\(error)"
                ])
                return [String: String]()
            }
        } else {
            let body = response.body?.asString() ?? "nil"
            logger.error("Cannot find any data in the bucket", metadata: [
                "response-body": .string(body)
            ])
            return [String: String]()
        }
    }

    public func save(items: [String: String]) async throws {
        let data = try encoder.encode(items)
        let putObjectRequest = S3.PutObjectRequest(
            acl: .private,
            body: .data(data),
            bucket: bucket,
            key: key
        )
        _ = try await s3.putObject(putObjectRequest)
    }
}
