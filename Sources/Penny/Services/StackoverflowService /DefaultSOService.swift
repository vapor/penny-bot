import AsyncHTTPClient
import NIOCore
import Foundation

struct DefaultSOService: SOService {
    let httpClient: HTTPClient
    let decoder = JSONDecoder()

    func listQuestions(after: Date) async throws -> [SOQuestions.Item] {
        let queries: KeyValuePairs = [
            "site": "stackoverflow",
            "tagged": "vapor",
            "nottagged": "laravel", /// Don't be a "laravel" questin
            "page": "1",
            "sort": "creation",
            "order": "desc",
            "fromdate": "\(Int(after.timeIntervalSince1970))",
            "pagesize": "100",
            "key": Constants.StackOverflow.apiKey,
        ]
        let url = "https://api.stackexchange.com/2.3/search/advanced" + queries.makeForURLQueryUnchecked()
        let request = HTTPClientRequest(url: url)
        let response = try await httpClient.execute(request, deadline: .now() + .seconds(15))
        let buffer = try await response.body.collect(upTo: 1 << 25) /// 32 MB
        let questions = try decoder.decode(
            SOQuestions.self,
            from: buffer
        ).items
        return questions
    }
}

private extension KeyValuePairs<String, String> {
    /// Doesn't do url-query encoding.
    /// Assumes the values are already safe.
    func makeForURLQueryUnchecked() -> String {
        "?" + self.map {
            "\($0)=\($1)"
        }.joined(separator: "&")
    }
}
