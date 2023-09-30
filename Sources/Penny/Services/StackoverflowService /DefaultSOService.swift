import AsyncHTTPClient
import NIOCore
import Foundation

struct DefaultSOService: SOService {
    let httpClient: HTTPClient
    let decoder = JSONDecoder()

    func listQuestions(after: Date) async throws -> [SOQuestions.Item] {
        let queries: [(String, String)] = [
            ("site", "stackoverflow"),
            ("tagged", "vapor"),
            ("page", "1"),
            ("sort", "creation"),
            ("order", "desc"),
            ("fromdate", "\(Int(after.timeIntervalSince1970))"),
            ("pagesize", "100"),
            ("key", Constants.StackOverflow.apiKey),
        ]
        let url = "https://api.stackexchange.com/2.3/questions" + queries.makeForURLQuery()
        let request = HTTPClientRequest(url: url)
        let response = try await httpClient.execute(request, deadline: .now() + .seconds(15))
        let buffer = try await response.body.collect(upTo: 1 << 25) /// 32 MB
        let questions = try decoder.decode(
            SOQuestions.self,
            from: buffer
        ).items.filter {
            /// Don't be a "laravel" question
            !$0.tags.contains { $0.contains("laravel") }
        }
        return questions
    }
}

extension [(String, String)] {
    private func makeForURLQuery() -> String {
        if self.isEmpty {
            return ""
        } else {
            return "?" + self.compactMap { key, value -> String? in
                let value = value.addingPercentEncoding(
                    withAllowedCharacters: .urlQueryAllowed
                ) ?? value
                return "\(key)=\(value)"
            }.joined(separator: "&")
        }
    }
}
