import Algorithms
import DiscordBM
import Shared

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Cache for detecting users who spam multiple channels at once.
actor SpamCache<ClockType: Clock> where ClockType.Instant.Duration == Swift.Duration {

    /// Only what is needed to detect the spam and to find the messages back in the Discord cache.
    struct Entry: Sendable {
        let messageId: MessageSnowflake
        let channelId: ChannelSnowflake
        let timestamp: ClockType.Instant

        init(message: Gateway.MessageCreate, now: ClockType.Instant) {
            self.messageId = message.id
            self.channelId = message.channel_id
            let lag = Duration.seconds(Date.now.timeIntervalSince(message.timestamp.date))
            self.timestamp = now.advanced(by: .zero - lag)
        }
    }

    enum Verdict: Sendable {
        case notSpam
        case spam(entries: [Entry])
        case alreadyFlagged
    }

    /// How far back a message is taken into account.
    static var window: Duration { .seconds(20) }
    /// How many distinct channels a user must post in, in a `window`, to be considered a spammer.
    static var channelThreshold: Int { 3 }
    /// Messages that arrive in this period after a flag are removed without reporting again.
    static var flagDuration: Duration { .seconds(60) }

    private let clock: ClockType
    private var entries: [UserSnowflake: [Entry]] = [:]
    private var flagged: [UserSnowflake: ClockType.Instant] = [:]

    init(clock: ClockType, runCleanupBackgroundTask: @escaping (@escaping @Sendable () async -> Void) -> Void) {
        self.clock = clock
        runCleanupBackgroundTask {
            await self.cleanupPeriodically()
        }
    }

    func recordAndCheck(
        _ message: Gateway.MessageCreate,
        of userId: UserSnowflake
    ) -> Verdict {
        let now = self.clock.now

        if let flaggedAt = self.flagged[userId],
            flaggedAt.duration(to: now) <= Self.flagDuration
        {
            return .alreadyFlagged
        }

        let newEntry = Entry(message: message, now: now)

        var recentMessages = self.entries.removeValue(forKey: userId) ?? []

        /// Messages don't necessarily arrive in the order they were sent, since we handle events concurrently.
        let highestTimestamp = max(
            newEntry.timestamp,
            recentMessages.lazy.map(\.timestamp).max() ?? newEntry.timestamp
        )
        recentMessages.removeAll { entry in
            entry.timestamp.duration(to: highestTimestamp) > Self.window
        }

        if let index = recentMessages.firstIndex(where: { $0.channelId == newEntry.channelId }) {
            /// Only 1 entry per channel is kept, and it must be the newest one of that channel
            /// even if it was not the last one to arrive.
            if recentMessages[index].timestamp < newEntry.timestamp {
                recentMessages[index] = newEntry
            }
        } else {
            recentMessages.append(newEntry)
        }

        assert(recentMessages.lazy.uniqued(on: \.channelId).count == recentMessages.count)

        if recentMessages.count < Self.channelThreshold {
            self.entries[userId] = recentMessages
            return .notSpam
        } else {
            self.flagged[userId] = now
            return .spam(entries: recentMessages)
        }
    }

    private func cleanupPeriodically() async {
        while true {
            guard (try? await Task.sleep(for: .seconds(10), clock: self.clock)) != nil else { return }
            self.cleanup()
        }
    }

    private func cleanup() {
        let now = self.clock.now
        self.entries = self.entries.compactMapValues { values in
            let shouldKeep = values.contains { $0.timestamp.duration(to: now) <= Self.window }
            return shouldKeep ? values : nil
        }

        self.flagged = self.flagged.filter { _, value in
            value.duration(to: now) <= Self.flagDuration
        }
    }
}
