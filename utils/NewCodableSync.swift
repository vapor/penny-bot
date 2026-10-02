#!/usr/bin/env swift
import Dispatch
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

let repository = "swiftlang/swift-foundation"
let branch = "experimental/new-codable"

/// Upstream source directory, and the target directory it is vendored into.
let vendoredDirectories: [(upstream: String, destination: String)] = [
    ("Sources/NewCodable", "Sources/NewCodable"),
    ("Sources/NewCodableMacros", "Sources/NewCodableMacros"),
    ("Sources/FoundationEssentials/NewCodable", "Sources/NewCodableFoundation"),
]

/// `experimental/new-codable` is an unreleased prototype branch that moves constantly. Rather
/// than tracking its tip, the sync picks the last commit made before the start of the current
/// week, so the resolved commit is identical for every run within a week and only rolls over
/// on Mondays.
func startOfCurrentWeek() -> Date {
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    guard let week = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
        fatalError("Could not determine the current week.")
    }
    return week.start
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
    request.setValue("penny-bot-NewCodableSync", forHTTPHeaderField: "User-Agent")
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

struct RemoteFile {
    let path: String
    let downloadURL: URL
}

func listFiles(in directory: String, at sha: String) -> [RemoteFile] {
    let url = URL(
        string: "https://api.github.com/repos/\(repository)/contents/\(directory)?ref=\(sha)"
    )!
    guard let entries = fetchJSON(url) as? [[String: Any]] else {
        fatalError("Could not list \(directory) at \(sha).")
    }

    var files: [RemoteFile] = []
    for entry in entries.sorted(by: { ($0["name"] as? String ?? "") < ($1["name"] as? String ?? "") }) {
        guard let path = entry["path"] as? String, let type = entry["type"] as? String else {
            fatalError("Malformed entry in \(directory): \(entry)")
        }
        switch type {
        case "dir":
            files.append(contentsOf: listFiles(in: path, at: sha))
        case "file":
            guard let downloadURL = (entry["download_url"] as? String).flatMap(URL.init(string:)) else {
                fatalError("No download URL for \(path)")
            }
            files.append(RemoteFile(path: path, downloadURL: downloadURL))
        default:
            fatalError("Unsupported entry type '\(type)' for \(path)")
        }
    }
    return files
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

    let cutoff = startOfCurrentWeek()
    print("Resolving the last \(branch) commit before \(iso8601(cutoff)) ...")
    let commit = resolveCommit(before: cutoff.addingTimeInterval(-1))
    print("Resolved \(commit.sha) (\(commit.date))")

    for (upstream, destination) in vendoredDirectories {
        print("Listing \(upstream) ...")
        let files = listFiles(in: upstream, at: commit.sha)

        if FileManager.default.fileExists(atPath: destination) {
            try! FileManager.default.removeItem(atPath: destination)
        }
        try! FileManager.default.createDirectory(
            atPath: destination,
            withIntermediateDirectories: true
        )

        for file in files {
            let relativePath = String(file.path.dropFirst(upstream.count + 1))
            let outputPath = "\(destination)/\(relativePath)"
            try! FileManager.default.createDirectory(
                atPath: (outputPath as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true
            )
            let data = try! fetchWithRetries(url: file.downloadURL)
            try! data.write(to: URL(fileURLWithPath: outputPath))
        }

        print("Vendored \(files.count) files into \(destination)")
    }

    print("Done!")
}

run()
