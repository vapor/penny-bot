import Foundation

public struct NoEnvVarError: Error, CustomStringConvertible {
    let key: String

    public var description: String {
        "NoEnvVarError(key.debugDescription: \(key.debugDescription))"
    }
}

public func requireEnvVar(_ key: String) throws -> String {
    if let value = ProcessInfo.processInfo.environment[key] {
        return value
    } else {
        throw NoEnvVarError(key: key)
    }
}
