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
    
    
    
    init(context: Lambda.InitializationContext) async throws {
        
    }
    
    func handle(_ event: APIGatewayV2Request, context: LambdaContext) async throws -> APIGatewayV2Response {
        var response: APIGatewayV2Response

        context.logger.info("Event body: \(event.body)")
        do {
            let verified = try event.verifyRequest()
            
            if !verified {
                return APIGatewayV2Response(statusCode: .unauthorized, body: "invalid request signature")
            }
            
            let discordResponse = Response(type: 1)
            response = APIGatewayV2Response(with: discordResponse, statusCode: .ok)
        }
        catch let error {
            print("\(error)")
            response = APIGatewayV2Response(statusCode: .badRequest, body: "Something went wrong parsing the request")
        }
        
        return response
    }
}

struct Response: Codable {
    let type: Int
}
