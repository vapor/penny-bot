import XCTest

extension XCTestCase {
    /// Fancy footwork to:
    /// 1- Avoid test failures just because of a new empty line at the end of the file.
    /// 2- Better errors about what exactly is causing the inequality.
    func XCTAssertMultilineStringsEqual(
        _ expression1: String,
        _ expression2: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expression1 = expression1.trimmingSuffix(while: \.isNewline)
        let expression2 = expression2.trimmingSuffix(while: \.isNewline)
        if expression1 != expression2 {
            /// Not using `whereSeparator: \.isNewline` so it doesn't match non `\n` characters.
            let lines1 = expression1
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingSuffix(while: \.isWhitespace) }
            let lines2 = expression2
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingSuffix(while: \.isWhitespace) }

            if lines1.count == lines2.count {
                for (idx, bothLines) in zip(lines1, lines2).enumerated() {
                    let (line1, line2) = bothLines
                    if line1 != line2 {
                        XCTFail(
                            """
                            Not equal at line \(idx + 1):
                            Expected: \(line1.debugDescription)
                            Got:      \(line2.debugDescription)
                            """,
                            file: file,
                            line: line
                        )
                    }
                }
            } else {
                XCTAssertEqual(expression1, expression2, file: file, line: line)
            }
        }
    }
}
