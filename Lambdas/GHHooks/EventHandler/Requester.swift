import AsyncHTTPClient
import DiscordBM
import GitHubAPI
import Logging
import Models
import NIOCore
import NIOHTTP1
import Shared

protocol GenericRequester: Sendable {
    func getDiscordMember(githubID: String) async throws -> GuildMember?
    func getCodeOwners(repoFullName: String, branch: some StringProtocol) async throws -> CodeOwners
}

/// A shared place for requests that more than 1 place uses.
struct Requester: Sendable {
    let eventName: GHEvent.Kind
    let event: GHEvent
    let httpClient: HTTPClient
    let discordClient: any DiscordClient
    let githubClient: Client
    let usersService: any UsersService
    let logger: Logger
}

extension Requester: GenericRequester {
    func getDiscordMember(githubID: String) async throws -> GuildMember? {
        guard let user = try await self.usersService.getUser(githubID: githubID) else {
            return nil
        }
        let response = try await self.discordClient.getGuildMember(
            guildId: Constants.guildID,
            userId: user.discordID
        )
        switch response.asError() {
        case let .jsonError(jsonError) where jsonError.code == .unknownMember:
            /// Left the server?
            return nil
        default: break
        }
        let member = try response.decode()
        return .init(
            uiName: member.uiName,
            uiAvatarURL: member.uiAvatarURL,
            userId: member.user?.id,
            roles: member.roles
        )
    }

    /// Returns code owners if the repo contains the file or returns `nil`.
    /// All lowercased.
    /// In form of `["gwynne", "0xtim"]`.
    func getCodeOwners(repoFullName: String, branch: some StringProtocol) async throws -> CodeOwners {
        let fullName = repoFullName.urlPathEncoded()
        let url = "https://raw.githubusercontent.com/\(fullName)/\(branch)/.github/CODEOWNERS"
        let request = HTTPClientRequest(url: url)
        let response = try await self.httpClient.execute(request, timeout: .seconds(5))
        let body = try await response.body.collect(upTo: 1 << 16)
        guard response.status == .ok else {
            logger.warning(
                "Can't find code owners of repo",
                metadata: [
                    "responseBody": "\(body)",
                    "response": "\(response)",
                ]
            )
            return CodeOwners(value: [])
        }
        let text = String(buffer: body)
        let parsed = parseCodeOwners(text: text)
        logger.debug(
            "Parsed code owners",
            metadata: [
                "text": .string(text),
                "parsed": .stringConvertible(parsed),
            ]
        )
        return parsed
    }
}

extension GenericRequester {
    /// Returns code owner names all lowercased.
    func parseCodeOwners(text: String) -> CodeOwners {
        let codeOwners: [String] =
            text
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

        return CodeOwners(value: codeOwners)
    }
}

struct GuildMember {
    var uiName: String?
    var uiAvatarURL: String?
    var userId: UserSnowflake?
    var roles: [RoleSnowflake]

    init(
        uiName: String? = nil,
        uiAvatarURL: String? = nil,
        userId: UserSnowflake? = nil,
        roles: [RoleSnowflake] = []
    ) {
        self.uiName = uiName
        self.uiAvatarURL = uiAvatarURL
        self.userId = userId
        self.roles = roles
    }
}

struct CodeOwners: CustomStringConvertible {
    var value: Set<String>

    var description: String {
        "CodeOwners(value: \(value))"
    }

    init(value: [String]) {
        self.value = Set(value.map({ $0.lowercased() }))
    }

    private init(lowercasedValue value: Set<String>) {
        self.value = value
    }

    /// Only supports names, and not emails.
    /// Assumes the strings are already all lowercased.
    func contains(user: User) -> Bool {
        if let name = user.name {
            return !self.value.intersection([user.login.lowercased(), name.lowercased()]).isEmpty
        } else {
            return self.value.contains(user.login.lowercased())
        }
    }

    /// Only supports names, and not emails.
    /// Assumes the strings are already all lowercased.
    func contains(user: NullableUser) -> Bool {
        if let name = user.name {
            return !self.value.intersection([user.login.lowercased(), name.lowercased()]).isEmpty
        } else {
            return self.value.contains(user.login.lowercased())
        }
    }

    func contains(login: String) -> Bool {
        self.value.contains(login.lowercased())
    }

    func union(_ other: Set<String>) -> CodeOwners {
        CodeOwners(
            lowercasedValue: self.value.union(
                other.map({ $0.lowercased() })
            )
        )
    }
}
