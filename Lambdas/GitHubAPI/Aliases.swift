#if canImport(FoundationEssentials)
import FoundationEssentials

package typealias FoundationData = FoundationEssentials.Data
package typealias FoundationDate = FoundationEssentials.Date
package typealias FoundationURL = FoundationEssentials.URL
#else
import struct Foundation.Data
import struct Foundation.Date
import struct Foundation.URL

package typealias FoundationData = Foundation.Data
package typealias FoundationDate = Foundation.Date
package typealias FoundationURL = Foundation.URL
#endif

package typealias Repository = Components.Schemas.repository
package typealias User = Components.Schemas.simple_user
package typealias Organization = Components.Schemas.organization_simple
package typealias PullRequest = Components.Schemas.pull_request
package typealias SimplePullRequest = Components.Schemas.pull_request_simple
package typealias Issue = Components.Schemas.issue
package typealias Label = Components.Schemas.label
package typealias Release = Components.Schemas.release
package typealias InstallationToken = Components.Schemas.installation_token
package typealias NullableUser = Components.Schemas.nullable_simple_user
package typealias Contributor = Components.Schemas.contributor
package typealias PullRequestReviewComment = Components.Schemas.pull_request_review_comment
package typealias PullRequestReview = Components.Schemas.pull_request_review
package typealias DiffEntry = Components.Schemas.diff_entry
package typealias Commit = Components.Schemas.commit
package typealias SimpleCommit = Components.Schemas.simple_commit
package typealias Committer = Components.Schemas.simple_commit.committerPayload
package typealias Enterprise = Components.Schemas.enterprise
package typealias Installation = Components.Schemas.simple_installation
package typealias Tag = Components.Schemas.tag
package typealias ProjectCard = Components.Schemas.project_card
package typealias TimelineIssueEvent = Components.Schemas.timeline_issue_events
