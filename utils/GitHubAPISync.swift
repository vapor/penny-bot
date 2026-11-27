#!/usr/bin/env swift
import Dispatch
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

let repository = "github/rest-api-description"
let branch = "main"
let upstreamSpecPath = "descriptions/api.github.com/api.github.com.yaml"

let specPath = "Lambdas/GitHubAPI/openapi.yaml"
let generatorConfigPath = "Lambdas/GitHubAPI/openapi-generator-config.yaml"
let generatedSourcesDirectory = "Lambdas/GitHubAPI/GeneratedSources"
let specPatch = "utils/patches/GitHubAPI/openapi.yaml.patch"
let generatedSourcesPatch = "utils/patches/GitHubAPI/GeneratedSources.patch"

/// GitHub updates its OpenAPI description several times a week. Rather than tracking its tip,
/// the sync picks the last commit made before the start of the current month, so the resolved
/// commit is identical for every run within a month and only rolls over on the first day of
/// each month.
func startOfCurrentMonth() -> Date {
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    guard let month = calendar.dateInterval(of: .month, for: Date()) else {
        fatalError("Could not determine the current month.")
    }
    return month.start
}

func iso8601(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(identifier: "UTC")!
    return formatter.string(from: date)
}

struct FetchError: Error, CustomStringConvertible {
    let url: URL
    let statusCode: Int

    var description: String {
        "HTTP \(statusCode) for \(url.absoluteString)"
    }
}

final class FetchBox: @unchecked Sendable {
    var data: Data?
    var error: (any Error)?
}

func fetchWithRetries(url: URL, isGitHubAPI: Bool = false) throws -> Data {
    var request = URLRequest(url: url)
    request.setValue("penny-bot-GitHubAPISync", forHTTPHeaderField: "User-Agent")
    if isGitHubAPI {
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let token = ProcessInfo.processInfo.environment["GITHUB_TOKEN"], !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    for attempt in 1...5 {
        let box = FetchBox()
        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                box.error = error
            } else if let response = response as? HTTPURLResponse, response.statusCode != 200 {
                box.error = FetchError(url: url, statusCode: response.statusCode)
            } else {
                box.data = data ?? Data()
            }
            semaphore.signal()
        }.resume()
        semaphore.wait()

        if let data = box.data {
            return data
        }

        let error = box.error ?? FetchError(url: url, statusCode: 0)
        if attempt == 5 {
            throw error
        }
        print("✗ Failed to fetch \(url.absoluteString): \(String(reflecting: error))")
        print("Retrying in 3 seconds...")
        Thread.sleep(forTimeInterval: 3)
    }

    fatalError("Unreachable.")
}

func fetchJSON(_ url: URL) -> Any {
    let data = try! fetchWithRetries(url: url, isGitHubAPI: true)
    return try! JSONSerialization.jsonObject(with: data)
}

struct Commit {
    let sha: String
    let date: String
}

func resolveCommit(before cutoff: Date) -> Commit {
    let url = URL(
        string: "https://api.github.com/repos/\(repository)/commits"
            + "?sha=\(branch)&until=\(iso8601(cutoff))&per_page=1"
    )!
    guard let commits = fetchJSON(url) as? [[String: Any]],
        let commit = commits.first,
        let sha = commit["sha"] as? String,
        let details = commit["commit"] as? [String: Any],
        let committer = details["committer"] as? [String: Any],
        let date = committer["date"] as? String
    else {
        fatalError("Could not resolve a commit on \(branch) before \(iso8601(cutoff)).")
    }
    return Commit(sha: sha, date: date)
}

func execute(_ arguments: [String]) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = arguments
    try! process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        fatalError("`\(arguments.joined(separator: " "))` failed with exit code \(process.terminationStatus).")
    }
}

func run() {
    let manifest = "Package.swift"
    guard FileManager.default.fileExists(atPath: manifest),
        try! String(contentsOfFile: manifest, encoding: .utf8).contains(#"name: "Penny""#)
    else {
        fatalError(
            "This script must be run from the penny-bot root directory. "
                + "Current directory: \(FileManager.default.currentDirectoryPath)."
        )
    }

    let cutoff = startOfCurrentMonth()
    print("Resolving the last \(branch) commit before \(iso8601(cutoff)) ...")
    let commit = resolveCommit(before: cutoff.addingTimeInterval(-1))
    print("Resolved \(commit.sha) (\(commit.date))")

    print("Downloading \(upstreamSpecPath) ...")
    let specURL = URL(
        string: "https://raw.githubusercontent.com/\(repository)/\(commit.sha)/\(upstreamSpecPath)"
    )!
    let spec = try! fetchWithRetries(url: specURL)
    try! spec.write(to: URL(fileURLWithPath: specPath))

    print("Applying \(specPatch) ...")
    execute(["git", "apply", specPatch])

    print("Building swift-openapi-generator ...")
    execute(["swift", "build", "--product", "swift-openapi-generator", "-c", "release"])

    if FileManager.default.fileExists(atPath: generatedSourcesDirectory) {
        try! FileManager.default.removeItem(atPath: generatedSourcesDirectory)
    }
    try! FileManager.default.createDirectory(
        atPath: generatedSourcesDirectory,
        withIntermediateDirectories: true
    )

    print("Generating \(generatedSourcesDirectory) ...")
    execute([
        ".build/release/swift-openapi-generator", "generate", specPath,
        "--config", generatorConfigPath,
        "--output-directory", generatedSourcesDirectory,
    ])

    print("Applying \(generatedSourcesPatch) ...")
    execute(["git", "apply", generatedSourcesPatch])

    print("Done!")
}

run()
