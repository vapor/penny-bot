
enum OptionalError: Error {
    case nilValue(type: String, file: String, function: String, line: UInt)
}

extension Optional {
    func require(
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) throws -> Wrapped {
        if let value = self {
            return value
        } else {
            throw OptionalError.nilValue(
                type: Swift._typeName(Self.self, qualified: false),
                file: file,
                function: function,
                line: line
            )
        }
    }
}
