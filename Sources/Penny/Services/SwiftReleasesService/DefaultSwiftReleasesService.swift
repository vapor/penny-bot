import AsyncHTTPClient
import Logging
import NIOCore
import NIOHTTP1
import NewCodable

struct DefaultSwiftReleasesService: SwiftReleasesService {
    let httpClient: HTTPClient
    let logger = Logger(label: "DefaultSwiftReleasesService")

    func listReleases() async throws -> [SwiftOrgRelease] {
        let url = "https://www.swift.org/api/v1/install/releases.json"
        let request = HTTPClientRequest(url: url)
        let response = try await httpClient.execute(request, deadline: .now() + .seconds(15))
        let buffer = try await response.body.collect(upTo: 1 << 25)
        /// 32 MiB

        guard 200..<300 ~= response.status.code else {
            let body = String(buffer: buffer)
            logger.error(
                "SwiftReleases-service failed",
                metadata: [
                    "status": "\(response.status)",
                    "headers": "\(response.headers)",
                    "body": "\(body)",
                ]
            )
            throw ServiceError.badStatus(response.status)
        }

        let releases = try NewJSONDecoder().decode(
            [SwiftOrgRelease].self,
            from: buffer.readableBytesSpan
        )
        return releases
    }
}
