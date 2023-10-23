import GitHubAPI

extension Issue {
    enum KnownLabel: String {
        case enhancement
        case bug
        case duplicate
        case wontFix = "wontfix"
        case invalid
        case helpWanted = "help wanted"
        case goodFirstIssue = "good first issue"
    }

    var knownLabels: [KnownLabel] {
        self.labels.compactMap(\.name).compactMap {
            KnownLabel(rawValue: $0)
        }
    }
}

private extension Issue.labelsPayloadPayload {
    var name: String? {
        switch self {
        case let .case1(string):
            return string
        case let .case2(payload):
            return payload.name
        }
    }
}
