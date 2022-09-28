//
//  File.swift
//  
//
//  Created by Mahdi Bahrami on 9/10/22.
//

import Foundation
import Logging
import DiscordBM

struct InteractionHandler {
    let discordClient: DiscordClient
    let logger: Logger
    let event: Gateway.InteractionCreate
    
    func handle() async {
        guard await sendInteractionAcknowledgement() else { return }
        let response = await processAndMakeResponse()
        //TODO: For debugging purposes, remove in production
        try? await Task.sleep(nanoseconds: 8 * 1_000_000_000)
        await respondToInteraction(with: response)
    }
    
    private func processAndMakeResponse() async -> String {
        guard let name = event.data?.name else {
            return "Failed to recognize the interaction"
        }
        var options = event.data?.options ?? []
        switch name {
        case "link":
            /// This is required based on the slash commands settings we send to discord.
            if options.isEmpty {
                return "Please provide more options"
            }
            let first = options.removeFirst()
            /// This is required based on the slash commands settings we send to discord.
            guard let id = first.options?.first?.value?.asString else {
                return "No ID option recognized"
            }
            switch first.name {
            case "discord":
                return "This command is still a WIP. Linking Discord with Discord ID \(id)"
            case "github":
                return "This command is still a WIP. Linking Discord with Github ID \(id)"
            case "slack":
                return "This command is still a WIP. Linking Discord with Slack ID \(id)"
            default:
                logger.error("Unrecognized link option: \(first.name)")
                return "Option not recognized: \(first.name)"
            }
        default:
            logger.error("Unrecognized command. Event: \(event)")
            return "Command not recognized"
        }
    }
    
    /// Returns if the acknowledgement was successfully sent
    private func sendInteractionAcknowledgement() async -> Bool {
        do {
            let apiResponse = try await discordClient.createInteractionResponse(
                id: event.id,
                token: event.token,
                payload: .init(type: .messageEditWithLoadingState)
            ).raw
            if !(200..<300).contains(apiResponse.status.code) {
                logger.error("Received non-200 status from Discord API for interaction acknowledgement: \(apiResponse)")
                return false
            } else {
                return true
            }
        } catch {
            logger.error("Discord Client error: \(error)")
            return false
        }
    }
    
    private func respondToInteraction(with response: String) async {
        do {
            let apiResponse = try await discordClient.editInteractionResponse(
                token: event.token,
                payload: .init(
                    embeds: [.init(
                        description: response,
                        color: .vaporPurple
                    )]
                )
            )
            if !(200..<300).contains(apiResponse.status.code) {
                logger.error("Received non-200 status from Discord API for interaction: \(apiResponse)")
            }
        } catch {
            logger.error("Discord Client error: \(error)")
        }
    }
}
