import SotoS3
import Foundation
import Models

package struct S3FaqsRepository {

    let s3: S3
    let logger: Logger
    let bucket = "penny-faqs-lambda"
    let key = "faqs-repo.json"

    let decoder = JSONDecoder()
    let encoder = JSONEncoder()

    package init(awsClient: AWSClient, logger: Logger) {
        self.s3 = S3(client: awsClient, region: .euwest1)
        self.logger = logger
    }

    package func insert(name: String, value: String) async throws -> [String: String] {
        var all = try await self.getAll()
        if all[name] != value {
            all[name] = value
            try await self.save(items: all)
        }
        return all
    }

    package func remove(name: String) async throws -> [String: String] {
        var all = try await self.getAll()
        if all.removeValue(forKey: name) != nil {
            try await self.save(items: all)
        }
        return all
    }

    package func getAll() async throws -> [String: String] {
        let response: S3.GetObjectOutput

        do {
            let request = S3.GetObjectRequest(bucket: bucket, key: key)
            response = try await s3.getObject(request, logger: logger)
        } catch {
            logger.error("Cannot retrieve the file from the bucket. If this is the first time, manually create a file named '\(self.key)' in bucket '\(self.bucket)' and set its content to empty json ('{}'). This has not been automated to reduce the chance of data loss", metadata: ["error": "\(error)"])
            throw error
        }

        let body = try await response.body.collect(upTo: 1 << 24)
        if body.readableBytes == 0 {
            logger.error("Cannot find any data in the bucket")
            return [String: String]()
        }
        do {
            return try decoder.decode([String: String].self, from: body)
        } catch {
            logger.error("Cannot find any data in the bucket", metadata: [
                "response-body": .string(String(buffer: body)),
                "error": "\(error)"
            ])
            return [String: String]()
        }
    }

    package func save(items: [String: String]) async throws {
        let data = try encoder.encode(items)
        let putObjectRequest = S3.PutObjectRequest(
            acl: .private,
            body: .init(bytes: data),
            bucket: bucket,
            key: key
        )
        _ = try await s3.putObject(putObjectRequest)
    }
}
