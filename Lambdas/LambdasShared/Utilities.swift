import Foundation

package struct NoEnvVarError: Error, CustomStringConvertible {
    let key: String

    package var description: String {
        "NoEnvVarError(key.debugDescription: \(key.debugDescription))"
    }
}

package func requireEnvVar(_ key: String) throws -> String {
    if let value = ProcessInfo.processInfo.environment[key] {
        return value
    } else {
        throw NoEnvVarError(key: key)
    }
}
