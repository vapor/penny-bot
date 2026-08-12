import Logging
package import Models
import NIOFoundationEssentialsCompat
package import SotoCore
import SotoLambda

#if canImport(FoundationEssentials)
import FoundationEssentials
import NIOFoundationEssentialsCompat
#else
import Foundation
import NIOFoundationCompat
#endif

package struct LambdaInvoker: Sendable {
    package enum Errors: Error, CustomStringConvertible {
        case functionError(functionName: Constants.LambdaFunctionName, error: String, payload: String)
        case lambdaFailure(functionName: Constants.LambdaFunctionName, reason: String)

        package var description: String {
            switch self {
            case let .functionError(functionName, error, payload):
                "functionError(functionName: \(functionName), error: \(error), payload: \(payload))"
            case let .lambdaFailure(functionName, reason):
                "lambdaFailure(functionName: \(functionName), reason: \(reason))"
            }
        }
    }

    private let lambda: Lambda
    private let logger = Logger(label: "LambdaInvoker")
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    package init(awsClient: AWSClient, region: Region = .euwest1) {
        self.lambda = Lambda(client: awsClient, region: region)
    }

    package func invokeUsersLambda(
        _ request: UsersLambdaRequest
    ) async throws -> UsersLambdaResponse {
        try await self.invoke(functionName: .users, request: request)
    }

    package func invokeAutoPingsLambda(
        _ request: AutoPingsLambdaRequest
    ) async throws -> S3AutoPingItems {
        try await self.invoke(functionName: .autoPings, request: request)
    }

    package func invokeFaqsLambda(
        _ request: FaqsLambdaRequest
    ) async throws -> [String: String] {
        try await self.invoke(functionName: .faqs, request: request)
    }

    package func invokeAutoFaqsLambda(
        _ request: AutoFaqsLambdaRequest
    ) async throws -> [String: String] {
        try await self.invoke(functionName: .autoFaqs, request: request)
    }

    private func invoke<
        Request: Sendable & Encodable,
        Success: Sendable & Codable
    >(
        functionName: Constants.LambdaFunctionName,
        request: Request,
        expecting: Success.Type = Success.self
    ) async throws -> Success {
        let data = try self.encoder.encode(request)
        let response = try await self.lambda.invoke(
            .init(
                functionName: functionName.rawValue,
                invocationType: .requestResponse,
                payload: .init(buffer: .init(data: data))
            ),
            logger: self.logger
        )

        /// 6 MiB, Lambda's synchronous response limit
        let payload = try await response.payload.collect(upTo: 6 * 1024 * 1024)

        if let functionError = response.functionError {
            throw Errors.functionError(
                functionName: functionName,
                error: functionError,
                payload: String(buffer: payload)
            )
        }

        switch try self.decoder.decode(LambdaResult<Success>.self, from: payload) {
        case let .success(success):
            return success
        case let .failure(reason):
            throw Errors.lambdaFailure(functionName: functionName, reason: reason)
        }
    }
}
