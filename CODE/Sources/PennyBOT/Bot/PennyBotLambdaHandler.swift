//
//  File.swift
//  
//
//  Created by Benny De Bock on 04/04/2022.
//

import AWSLambdaRuntime
import AWSLambdaEvents
import Foundation
import PennyModels
import PennyExtensions
import Swiftcord

@main
struct Bot: LambdaHandler {
    typealias Event = APIGatewayV2Request
    typealias Output = APIGatewayV2Response
    
    let PUBLIC_KEY = ProcessInfo.processInfo.environment["PUBLIC_KEY"]
    
    init(context: Lambda.InitializationContext) async throws {
        
    }
    
    func handle(_ event: APIGatewayV2Request, context: LambdaContext) async throws -> APIGatewayV2Response {
        context.logger.info("Event: \(event)")
        context.logger.info("Event body: \(event.body)")
        do {
            
            let verified = try event.verifyRequest(with: (PUBLIC_KEY?.data(using: .utf8))!)
            
            if !verified {
                return APIGatewayV2Response(statusCode: .unauthorized, body: "invalid request signature")
            }
        }
        catch {
            
        }
        let response = Response(type: 1)
        return APIGatewayV2Response(with: response, statusCode: .ok)
    }
}

struct Response: Codable {
    let type: Int
}
