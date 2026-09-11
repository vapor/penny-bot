import Shared

enum CommentCommand: String, CaseIterable {
    case benchmark
}

extension CommentCommand {
    enum ParseResult: Equatable {
        case noMention
        case unknownCommand(verb: String?)
        case command(CommentCommand)
    }

    static let mentions = ["@penny-for-vapor", "@penny"]

    static func parse(commentBody: String) -> ParseResult {
        var isInFence = false
        var sawMention = false
        var unknownVerb: String?

        for line in commentBody.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            guard let leadingByte = Self.firstNonBlankByte(of: line) else { continue }

            switch leadingByte {
            case UInt8(ascii: "`"), UInt8(ascii: "~"):
                if Self.isFenceDelimiter(line) {
                    isInFence.toggle()
                }
            case UInt8(ascii: "@") where !isInFence:
                let normalized = line.trimmingWhitespaces().lowercased()
                guard let rest = Self.strippingMention(from: normalized) else { continue }

                sawMention = true

                guard let verb = rest.split(whereSeparator: \.isWhitespace).first else { continue }
                guard let command = CommentCommand(rawValue: String(verb)) else {
                    /// Keep the first unrecognized verb, but keep looking in case a later line
                    /// carries a real command.
                    unknownVerb = unknownVerb ?? String(verb)
                    continue
                }

                return .command(command)
            default:
                /// Early-exit for most comments that are not commands.
                continue
            }
        }

        return sawMention ? .unknownCommand(verb: unknownVerb) : .noMention
    }

    /// The first byte that is neither a space nor a tab, or `nil` for a blank line.
    private static func firstNonBlankByte(of line: Substring) -> UInt8? {
        for byte in line.utf8 where byte != UInt8(ascii: " ") && byte != UInt8(ascii: "\t") {
            return byte
        }
        return nil
    }

    private static func isFenceDelimiter(_ line: Substring) -> Bool {
        let trimmed = line.drop(while: \.isWhitespace)
        return trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~")
    }

    private static func strippingMention(from line: String) -> String? {
        for mention in Self.mentions where line.hasPrefix(mention) {
            let rest = line.dropFirst(mention.count)
            guard rest.first?.isWhitespace ?? true else { continue }
            return rest.trimmingWhitespaces()
        }
        return nil
    }
}
