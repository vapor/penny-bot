import Algorithms
import Testing

/// Fancy footwork to:
/// 1- Avoid test failures just because of a new empty line at the end of a file.
/// 2- Avoid test failures just because of some whitespaces at the end of a line.
/// 3- Better errors about what exactly is causing the inequality.
func expectMultilineStringsEqual(
    _ expression1: String,
    _ expression2: String,
    sourceLocation: Testing.SourceLocation = #_sourceLocation
) {
    let expression1 = expression1.trimmingSuffix(while: \.isNewline)
    let expression2 = expression2.trimmingSuffix(while: \.isNewline)
    if expression1 != expression2 {
        /// Not using `whereSeparator: \.isNewline` so it doesn't match non `\n` characters.
        let lines1 =
            expression1
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingSuffix(while: \.isWhitespace) }
        let lines2 =
            expression2
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingSuffix(while: \.isWhitespace) }

        if lines1.count == lines2.count {
            for (idx, (line1, line2)) in zip(lines1, lines2).enumerated() {
                if line1 != line2 {
                    Issue.record(
                        """
                        Not equal at line \(idx + 1):
                        Got:      \(line1.debugDescription)
                        Expected: \(line2.debugDescription)
                        """,
                        sourceLocation: sourceLocation
                    )
                }
            }
        } else {
            #expect(expression1 == expression2, sourceLocation: sourceLocation)
        }
    }
}
