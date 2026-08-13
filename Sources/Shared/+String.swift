extension String {
    package func urlPathEncoded() -> String {
        self.percentEncoded(
            allowedBytes: urlPathAllowedBytes,
            allowsColonAfterASlash: true
        )
    }

    package func urlQueryEncoded() -> String {
        self.percentEncoded(
            allowedBytes: urlQueryAllowedBytes,
            allowsColonAfterASlash: false
        )
    }

    /// Matches what `Foundation`'s `addingPercentEncoding(withAllowedCharacters:)` produces for
    /// `.urlPathAllowed` and `.urlQueryAllowed`, without needing `Foundation` itself.
    private func percentEncoded(allowedBytes: [Bool], allowsColonAfterASlash: Bool) -> String {
        var didPassASlash = false

        /// Nothing to encode is by far the common case, so don't allocate for it.
        guard
            self.utf8.contains(where: {
                !isAllowedInPercentEncoded($0, allowedBytes, allowsColonAfterASlash, &didPassASlash)
            })
        else {
            return self
        }

        var encoded = ""
        encoded.reserveCapacity(self.utf8.count)

        /// The scan above stopped at the first disallowed byte, so start the slash tracking over.
        didPassASlash = false

        for byte in self.utf8 {
            if isAllowedInPercentEncoded(byte, allowedBytes, allowsColonAfterASlash, &didPassASlash) {
                encoded.unicodeScalars.append(Unicode.Scalar(byte))
            } else {
                encoded.unicodeScalars.append("%")
                encoded.unicodeScalars.append(hexUppercasedDigits[Int(byte >> 4)])
                encoded.unicodeScalars.append(hexUppercasedDigits[Int(byte & 0xF)])
            }
        }

        return encoded
    }

    func isAllowedInPercentEncoded(
        _ byte: UInt8,
        _ allowedBytes: [Bool],
        _ allowsColonAfterASlash: Bool,
        _ didPassASlash: inout Bool
    ) -> Bool {
        if allowedBytes[Int(byte)] {
            if byte == UInt8(ascii: "/") {
                didPassASlash = true
            }
            return true
        }
        return allowsColonAfterASlash && didPassASlash && byte == UInt8(ascii: ":")
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

/// `StringProtocol` is basically either `String` or `Substring`.
extension StringProtocol {
    /// Equivalent of `Foundation`'s `trimmingCharacters(in: .whitespaces)`.
    package func trimmingWhitespaces() -> String {
        self.trimming(while: { isWhitespaceScalar($0) && !isNewlineScalar($0) })
    }

    /// Equivalent of `Foundation`'s `trimmingCharacters(in: .whitespacesAndNewlines)`.
    package func trimmingWhitespacesAndNewlines() -> String {
        self.trimming(while: isWhitespaceScalar)
    }

    /// Trims unicode scalars, not `Character`s, which is what `Foundation` does as well. The
    /// standard library only offers `trimmingPrefix(while:)`, so no trailing-side trimming.
    private func trimming(while shouldTrim: (Unicode.Scalar) -> Bool) -> String {
        let scalars = self.unicodeScalars
        var startIndex = scalars.startIndex
        var endIndex = scalars.endIndex

        while startIndex < endIndex, shouldTrim(scalars[startIndex]) {
            scalars.formIndex(after: &startIndex)
        }

        while startIndex < endIndex {
            let beforeEndIndex = scalars.index(before: endIndex)
            guard shouldTrim(scalars[beforeEndIndex]) else { break }
            endIndex = beforeEndIndex
        }

        /// Nothing to trim is the common case, so skip rebuilding the scalar view for it.
        guard startIndex != scalars.startIndex || endIndex != scalars.endIndex else {
            return String(self)
        }

        return String(String.UnicodeScalarView(scalars[startIndex..<endIndex]))
    }

    /// A cheap stand-in for `Foundation`'s `folding(options: .diacriticInsensitive, locale: nil)`.
    /// Exact for the Latin-1 Supplement and Latin Extended-A blocks, and for any diacritics that
    /// are already decomposed. Anything else is left as-is.
    package func foldingDiacritics() -> String {
        /// Most strings carry no diacritics at all, so don't allocate for them.
        guard self.unicodeScalars.contains(where: \.needsDiacriticFolding) else {
            return String(self)
        }

        var folded = ""
        folded.reserveCapacity(self.unicodeScalars.count)

        for scalar in self.unicodeScalars {
            switch scalar.value {
            case 0x00C0...0x00FF:
                folded.unicodeScalars.append(latin1SupplementBases[Int(scalar.value - 0x00C0)] ?? scalar)
            case 0x0100...0x017F:
                folded.unicodeScalars.append(latinExtendedABases[Int(scalar.value - 0x0100)] ?? scalar)
            default:
                if scalar.properties.generalCategory != .nonspacingMark {
                    folded.unicodeScalars.append(scalar)
                }
            }
        }

        return folded
    }
}

extension String {
    /// Unlike `hashValue`, this is stable across processes, so it's safe to persist or to
    /// round-trip through Discord.
    package var stableHash: Int {
        Int(crc32(self.utf8Span.span))
    }
}

/// Base letters of `U+00C0...U+00FF`, in order. `nil` means "no folding".
private let latin1SupplementBases: [Unicode.Scalar?] = [
    "A", "A", "A", "A", "A", "A", nil, "C",
    "E", "E", "E", "E", "I", "I", "I", "I",
    nil, "N", "O", "O", "O", "O", "O", nil,
    nil, "U", "U", "U", "U", "Y", nil, nil,
    "a", "a", "a", "a", "a", "a", nil, "c",
    "e", "e", "e", "e", "i", "i", "i", "i",
    nil, "n", "o", "o", "o", "o", "o", nil,
    nil, "u", "u", "u", "u", "y", nil, "y",
]

/// Base letters of `U+0100...U+017F`, in order. `nil` means "no folding".
private let latinExtendedABases: [Unicode.Scalar?] = [
    "A", "a", "A", "a", "A", "a", "C", "c",
    "C", "c", "C", "c", "C", "c", "D", "d",
    nil, nil, "E", "e", "E", "e", "E", "e",
    "E", "e", "E", "e", "G", "g", "G", "g",
    "G", "g", "G", "g", "H", "h", nil, nil,
    "I", "i", "I", "i", "I", "i", "I", "i",
    "I", nil, nil, nil, "J", "j", "K", "k",
    nil, "L", "l", "L", "l", "L", "l", nil,
    nil, nil, nil, "N", "n", "N", "n", "N",
    "n", nil, nil, nil, "O", "o", "O", "o",
    "O", "o", nil, nil, "R", "r", "R", "r",
    "R", "r", "S", "s", "S", "s", "S", "s",
    "S", "s", "T", "t", "T", "t", nil, nil,
    "U", "u", "U", "u", "U", "u", "U", "u",
    "U", "u", "U", "u", "W", "w", "Y", "y",
    "Y", "Z", "z", "Z", "z", "Z", "z", nil,
]

extension Unicode.Scalar {
    /// Whether `foldingDiacritics()` would rewrite or drop this scalar. Must mirror it exactly.
    fileprivate var needsDiacriticFolding: Bool {
        switch self.value {
        case 0x0000...0x007F: false
        case 0x00C0...0x00FF: latin1SupplementBases[Int(self.value - 0x00C0)] != nil
        case 0x0100...0x017F: latinExtendedABases[Int(self.value - 0x0100)] != nil
        default: self.properties.generalCategory == .nonspacingMark
        }
    }
}

/// The scalars of `Foundation`'s `CharacterSet.whitespacesAndNewlines`. On top of the scalars
/// carrying the `White_Space` Unicode property, it also contains `U+200B ZERO WIDTH SPACE`, which
/// hasn't been `White_Space` since Unicode 4.0.1.
private func isWhitespaceScalar(_ scalar: Unicode.Scalar) -> Bool {
    scalar.properties.isWhitespace || scalar.value == 0x200B
}

/// The scalars of `Foundation`'s `CharacterSet.newlines`.
/// `Unicode.Scalar.isNewline` exists, but is `internal` to the standard library.
private func isNewlineScalar(_ scalar: Unicode.Scalar) -> Bool {
    switch scalar.value {
    case 0x0A...0x0D, 0x85, 0x2028, 0x2029: true
    default: false
    }
}

private let hexUppercasedDigits: [Unicode.Scalar] = [
    "0", "1", "2", "3", "4", "5", "6", "7",
    "8", "9", "A", "B", "C", "D", "E", "F",
]

/// Alphanumerics plus `!$&'()*+,-./;=@_~`, indexed by byte value.
private let urlPathAllowedBytes: [Bool] = [
    false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
    false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
    false, true, false, false, true, false, true, true, true, true, true, true, true, true, true, true,
    true, true, true, true, true, true, true, true, true, true, false, true, false, true, false, false,
    true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true,
    true, true, true, true, true, true, true, true, true, true, true, false, false, false, false, true,
    false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true,
    true, true, true, true, true, true, true, true, true, true, true, false, false, false, true, false,
    false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
    false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
    false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
    false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
    false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
    false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
    false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
    false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
]

/// Alphanumerics plus `!$&'()*+,-./:;=?@_~`, indexed by byte value.
private let urlQueryAllowedBytes: [Bool] = [
    false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
    false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
    false, true, false, false, true, false, true, true, true, true, true, true, true, true, true, true,
    true, true, true, true, true, true, true, true, true, true, true, true, false, true, false, true,
    true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true,
    true, true, true, true, true, true, true, true, true, true, true, false, false, false, false, true,
    false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true,
    true, true, true, true, true, true, true, true, true, true, true, false, false, false, true, false,
    false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
    false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
    false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
    false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
    false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
    false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
    false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
    false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
]
