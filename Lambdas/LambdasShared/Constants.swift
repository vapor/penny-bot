
public enum Constants {
    public enum ARNEnvVarKey: String, Sendable, CustomStringConvertible {
        case botToken = "BOT_TOKEN_ARN"
        case githubWorkflowToken = "GH_WORKFLOW_TOKEN_ARN"
        case githubClientSecret = "GH_CLIENT_SECRET_ARN"
        case githubAppPrivateKey = "GH_APP_AUTH_PRIV_KEY_ARN"
        case webhookSecret = "WH_SECRET_ARN"

        public var description: String {
            self.rawValue
        }
    }
}
