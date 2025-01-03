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

package typealias Repository = Components.Schemas.Repository
package typealias User = Components.Schemas.SimpleUser
package typealias Organization = Components.Schemas.OrganizationSimple
package typealias PullRequest = Components.Schemas.PullRequest
package typealias SimplePullRequest = Components.Schemas.PullRequestSimple
package typealias Issue = Components.Schemas.Issue
package typealias Label = Components.Schemas.Label
package typealias Release = Components.Schemas.Release
package typealias InstallationToken = Components.Schemas.InstallationToken
package typealias NullableUser = Components.Schemas.NullableSimpleUser
package typealias Contributor = Components.Schemas.Contributor
package typealias PullRequestReviewComment = Components.Schemas.PullRequestReviewComment
package typealias PullRequestReview = Components.Schemas.PullRequestReview
package typealias DiffEntry = Components.Schemas.DiffEntry
package typealias Commit = Components.Schemas.Commit
package typealias SimpleCommit = Components.Schemas.Commit
package typealias Committer = Components.Schemas.Commit.CommitterPayload
package typealias Enterprise = Components.Schemas.Enterprise
package typealias Installation = Components.Schemas.Installation
package typealias Tag = Components.Schemas.Tag
package typealias ProjectCard = Components.Schemas.ProjectCard
package typealias TimelineIssueEvents = Components.Schemas.TimelineIssueEvents
