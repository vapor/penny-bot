import NIOCore
import Rendering
import Logging
@preconcurrency import AsyncHTTPClient
import Foundation

extension LeafRenderer {
    static func forGHHooks(httpClient: HTTPClient, logger: Logger) throws -> LeafRenderer {
        try LeafRenderer(
            subDirectory: "GHHooksLambda",
            httpClient: httpClient,
            extraSources: [DocsLeafSource(
                httpClient: httpClient,
                logger: logger
            )],
            logger: logger,
            on: httpClient.eventLoopGroup.next()
        )
    }
}

private struct DocsLeafSource: LeafSource {

    enum Configuration {
        static var supportedFileNames: Set<String> {
            ["translation_needed.description.leaf"]
        }
    }

    enum Errors: Error, CustomStringConvertible {
        case unsupportedTemplate(String)
        case badStatusCode(response: HTTPClient.Response)
        case emptyBody(template: String, response: HTTPClient.Response)

        var description: String {
            switch self {
            case .unsupportedTemplate(let template):
                return "unsupportedTemplate(\(template))"
            case .badStatusCode(let response):
                return "badStatusCode(\(response))"
            case .emptyBody(let template, let response):
                return "emptyBody(template: \(template), response: \(response))"
            }
        }
    }

    let httpClient: HTTPClient
    let logger: Logger

    func file(
        template: String,
        escape: Bool,
        on eventLoop: any EventLoop
    ) throws -> EventLoopFuture<ByteBuffer> {
        guard Configuration.supportedFileNames.contains(template) else {
            return eventLoop.makeFailedFuture(Errors.unsupportedTemplate(template))
        }
        let repoURL = "https://raw.githubusercontent.com/vapor/docs/main"
        let url = "\(repoURL)/.github/\(template)"
        let request = try HTTPClient.Request(url: url)
        return httpClient.execute(request: request).flatMapThrowing { response in
            guard 200..<300 ~= response.status.code else {
                throw Errors.badStatusCode(response: response)
            }
            guard let body = response.body else {
                throw Errors.emptyBody(template: template, response: response)
            }
            return body
        }
    }
}
