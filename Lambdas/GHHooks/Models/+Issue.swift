
extension Issue {
    enum Action: String, Codable {
        case assigned
        case closed
        case deleted
        case demilestoned
        case edited
        case labeled
        case locked
        case milestoned
        case opened
        case pinned
        case reopened
        case transferred
        case unassigned
        case unlabeled
        case unlocked
        case unpinned
    }
}
