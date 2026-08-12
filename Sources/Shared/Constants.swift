import DiscordBM

package enum Constants {
    static let guildID: GuildSnowflake = "431917998102675485"

    package enum LambdaFunctionName: String {
        case users = "UsersLambda"
        case autoPings = "AutoPingsLambda"
        case faqs = "FaqsLambda"
        case autoFaqs = "AutoFaqsLambda"
    }
}
