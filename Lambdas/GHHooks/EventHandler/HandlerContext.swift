import AsyncHTTPClient
import DiscordBM
import GitHubAPI
import OpenAPIRuntime
import Rendering
import SharedServices
import Logging

struct HandlerContext {
    let eventName: GHEvent.Kind
    let event: GHEvent
    let httpClient: HTTPClient
    let discordClient: any DiscordClient
    let githubClient: Client
    let renderClient: RenderClient
    let messageLookupRepo: any MessageLookupRepo
    let usersService: any UsersService
    let logger: Logger
}

extension HandlerContext {
    func getDiscordMember(githubID: String) async throws -> Guild.Member? {
        guard let user = try await self.usersService.getUser(githubID: githubID) else {
            return nil
        }
        let response = try await self.discordClient.getGuildMember(
            guildId: Constants.guildID,
            userId: user.discordID
        )
        switch response.asError() {
        case let .jsonError(jsonError) where jsonError.code == .unknownMember:
            return nil
        default: break
        }
        return try response.decode()
    }

    /// Returns code owners if the repo contains the file or returns `nil`.
    /// In form of `["gwynne", "0xTim"]`.
    func getCodeOwners(repoFullName: String) async throws -> Set<String> {
        let fullName = repoFullName.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? repoFullName
        let url = "https://raw.githubusercontent.com/\(fullName)/main/.github/CODEOWNERS"
        let request = HTTPClientRequest(url: url)
        let response = try await self.httpClient.execute(request, timeout: .seconds(5))
        let body = try await response.body.collect(upTo: 1 << 16)
        guard response.status == .ok else {
            logger.warning("Can't find code owners of repo", metadata: [
                "responseBody": "\(body)",
                "response": "\(response)"
            ])
            return []
        }
        let text = String(buffer: body)
        let parsed = parseCodeOwners(text: text)
        logger.debug("Parsed code owners", metadata: [
            "text": .string(text),
            "parsed": .stringConvertible(parsed)
        ])
        return parsed
    }

    func parseCodeOwners(text: String) -> Set<String> {
        let codeOwners: [String] = text
        /// split into lines
            .split(omittingEmptySubsequences: true, whereSeparator: \.isNewline)
        /// trim leading whitespace per line
            .map { $0.trimmingPrefix(while: \.isWhitespace) }
        /// remove whole-line comments
            .filter { !$0.starts(with: "#") }
        /// remove partial-line comments
            .compactMap {
                $0.split(
                    separator: "#",
                    maxSplits: 1,
                    omittingEmptySubsequences: true
                ).first
            }
        /// split lines on whitespace, dropping first character, and combine to single list
            .flatMap { line -> [Substring] in
                line.split(
                    omittingEmptySubsequences: true,
                    whereSeparator: \.isWhitespace
                ).dropFirst().map { (user: Substring) -> Substring in
                    /// Drop the first character of each code-owner which is an `@`.
                    if user.first == "@" {
                        return user.dropFirst()
                    } else {
                        return user
                    }
                }
            }.map(String.init)

        return Set(codeOwners)
    }
}
