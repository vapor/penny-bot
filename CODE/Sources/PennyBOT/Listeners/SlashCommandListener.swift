//
//  File.swift
//  
//
//  Created by Benny De Bock on 30/03/2022.
//

/*import Foundation
import Swiftcord

class SlashCommandListener {
    let bot: Swiftcord
    let guildId: Snowflake = 431917998102675485
    
    init(bot: Swiftcord) {
        self.bot = bot
    }
    
    func BuildCommands() {
        let linkGithubCommand = SlashCommandBuilder(name: "Link Github", description: "Used to link your github account to your discord account in Penny, beware as this command will always overwrite the last Github account that was linked")
            .addOption(option: ApplicationCommandOptions(name: "Github AccountID", description: "The Github ID of the account you want to link", type: .string))
        let linkDiscordCommand = SlashCommandBuilder(name: "Link Discord", description: "Used to link your discord account to your github account in Penny, beware as this command will always overwrite the last Discord that was linked")
            .addOption(option: ApplicationCommandOptions(name: "Github AccountID", description: "The Github ID of the account you want your Discord to link with", type: .string))
        
        bot.guilds[guildId]!.uploadSlashCommand(commandData: linkGithubCommand)
        bot.guilds[guildId]!.uploadSlashCommand(commandData: linkDiscordCommand)
    }
    
    func ListenToSlashCommands() {
        self.bot.on(.slashCommandEvent) { data in
            var event = data as! SlashCommandEvent
            
            switch event.name {
            case "Link Github":
                event.setEphemeral(isEphermeral: true)
                let githubId = event.getOptionAsString(optionName: "Github AccountID")!
                event.reply(message: "This command is still a WIP. Linking Github with GH ID \(githubId)")
            case "Link Discord":
                event.setEphemeral(isEphermeral: true)
                let githubId = event.getOptionAsString(optionName: "Github AccountID")!
                event.reply(message: "This command is still a WIP. Linking Discord with GH ID \(githubId)")
            default:
                print("Not a slash command")
            }
        }
    }
}*/
