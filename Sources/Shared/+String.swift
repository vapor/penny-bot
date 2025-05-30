/// Import full foundation even on linux for `addingPercentEncoding`, for now.
import Foundation

extension String {
    package func urlPathEncoded() -> String {
        self.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? self
    }

    @_disfavoredOverload
    package func unicodesPrefix(_ maxUnicodeScalars: Int) -> (remaining: Int, result: String) {
        /// Well, I mean, you _can_, but you won't like the resulting infinite loop!
        assert(maxUnicodeScalars > 0, "Can't request a non-positive maximum.")

        let delta = maxUnicodeScalars - self.unicodeScalars.count

        /// Early exit: Do we need to trim at all?
        guard delta.signum() == -1 else {
            return (delta, self)
        }

        /// Take a prefix of the string (i.e. a sequence of extended grapheme clusters) first.
        /// Most of the time, this will already be short enough.
        var trimmed = self.prefix(maxUnicodeScalars)

        /// If the result still has too many unicode scalars, there're one or more grapheme
        /// clusters in the string. Keep dropping extended grapheme clusters off the end (which
        /// with `String` is as easy as just removing the last `Character`) until we're within
        /// bounds. Worst-case complexity is `O(n)`.
        while trimmed.unicodeScalars.count >= maxUnicodeScalars {
            trimmed.removeLast()
        }

        /// Append `U+2026 HORIZONTAL ELLIPSIS`
        trimmed.append("\u{2026}")

        return (0, String(trimmed))
    }

    package func unicodesPrefix(_ maxUnicodeScalars: Int) -> String {
        unicodesPrefix(maxUnicodeScalars).result
    }

    package func quotedMarkdown() -> String {
        self.split(
            omittingEmptySubsequences: false,
            whereSeparator: \.isNewline
        ).map {
            "> \($0)"
        }.joined(
            separator: "\n"
        )
    }
}
