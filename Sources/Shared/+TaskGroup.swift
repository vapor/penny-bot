import Foundation

/// Accumulates errors while performing the tasks concurrently.
/// The primary purpose of this is so e.g. if the first task fails, the next tasks still run.
package func withThrowingAccumulatingVoidTaskGroup(
    tasks: [@Sendable () async throws -> Void]
) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
        for task in tasks {
            group.addTask {
                try await task()
            }
        }

        var errors: [any Error] = []
        while let result = await group.nextResult() {
            switch result {
            case let .failure(error):
                errors.append(error)
            case .success: break
            }
        }

        guard errors.isEmpty else {
            throw MultipleErrors(errors)
        }
    }
}

struct MultipleErrors: CustomStringConvertible, LocalizedError {
    let errors: [any Error]

    init(_ errors: [any Error]) {
        self.errors = errors
    }

    var description: String {
        "MultipleErrors { \(errors.map({ String(reflecting: $0) }).joined(separator: "; ")) }"
    }

    var errorDescription: String? {
        self.description
    }
}
