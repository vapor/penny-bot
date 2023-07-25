import DiscordBM
import DiscordLogger
import Logging
import AsyncHTTPClient
import NIOCore
import Foundation

//enum DiscordFactory {
//    static var makeBot: (any EventLoopGroup, HTTPClient) async -> any GatewayManager = {
//        eventLoopGroup, client in
//        
//    }
//    
//    static var makeCache: (any GatewayManager) async -> DiscordCache = {
//        await DiscordCache(
//            gatewayManager: $0,
//            intents: [.guilds, .guildMembers],
//            requestAllMembers: .enabled
//        )
//    }
//
//    static var bootstrapLoggingSystem: (HTTPClient) async -> Void = { httpClient in
//
//    }
//}
