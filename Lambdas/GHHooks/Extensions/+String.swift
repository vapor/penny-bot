
extension String {
    func unicodesPrefix(_ maxUnicodeScalars: Int) -> String {
        /// Well, I mean, you _can_, but you won't like the resulting infinite loop!
        assert(maxUnicodeScalars > 0, "Can't request a non-positive maximum.")

        /// Early exit: Do we need to trim at all?
        guard self.unicodeScalars.count > maxUnicodeScalars else { return self }

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

        return String(trimmed)
    }
}
