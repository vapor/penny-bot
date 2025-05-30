import AsyncHTTPClient
/// Import full foundation even on linux for `urlQueryAllowed`, for now.
import Foundation
import Logging
import NIOCore
import NIOFoundationCompat
import NIOHTTP1

struct DefaultSOService: SOService {
    let httpClient: HTTPClient
    let logger = Logger(label: "DefaultSOService")
    let decoder = JSONDecoder()
    private static let urlEncodedAPIKey = Constants.StackOverflow.apiKey
        .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!

    func listQuestions(after: Date) async throws -> [SOQuestions.Item] {
        let queries: KeyValuePairs = [
            "site": "stackoverflow",
            "tagged": "vapor",
            "nottagged": "laravel",
            /// Don't be a "laravel" question
            "page": "1",
            "sort": "creation",
            "order": "desc",
            "fromdate": "\(Int(after.timeIntervalSince1970))",
            "pagesize": "100",
            "key": Self.urlEncodedAPIKey,
        ]
        let url = "https://api.stackexchange.com/2.3/search/advanced" + queries.makeForURLQueryUnchecked()
        let request = HTTPClientRequest(url: url)
        let response = try await httpClient.execute(request, deadline: .now() + .seconds(15))
        let buffer = try await response.body.collect(upTo: 1 << 25)
        /// 32 MiB

        guard 200..<300 ~= response.status.code else {
            let body = String(buffer: buffer)
            logger.error(
                "SO-service failed",
                metadata: [
                    "status": "\(response.status)",
                    "headers": "\(response.headers)",
                    "body": "\(body)",
                ]
            )
            throw ServiceError.badStatus(response.status)
        }

        let questions = try decoder.decode(
            SOQuestions.self,
            from: buffer
        ).items
        return questions
    }
}

extension KeyValuePairs<String, String> {
    /// Doesn't do url-query encoding.
    /// Assumes the values are already safe.
    fileprivate func makeForURLQueryUnchecked() -> String {
        "?" + self.map { "\($0)=\($1)" }.joined(separator: "&")
    }
}
