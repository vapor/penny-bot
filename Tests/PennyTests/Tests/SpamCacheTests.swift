import DiscordModels
import Shared
import Testing

@testable import Penny

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@Suite
struct SpamCacheTests {

    private let spammer: UserSnowflake = "1032312357818151033"
    private let channels: [ChannelSnowflake] = [
        "519613337638797315",
        "684159753189982218",
        "1018169583619821619",
    ]

    private func makeMessage(
        id: MessageSnowflake,
        inChannel index: Int,
        of userId: UserSnowflake,
        sentSecondsAgo secondsAgo: Double = 0
    ) -> Gateway.MessageCreate {
        TestData.rolelessMessage(
            id: id,
            channelId: channels[index],
            authorId: userId,
            content: "free nitro at https://example.com",
            timestamp: Date(timeIntervalSinceNow: -secondsAgo)
        )
    }

    @Test
    func twoChannelsAreNotSpam() async throws {
        let clock = ManualClock()
        let cache = SpamCache(clock: clock, runCleanupBackgroundTask: { _ in })

        for index in 0..<2 {
            let message = makeMessage(id: try .makeFake(), inChannel: index, of: spammer)
            let verdict = await cache.recordAndCheck(message, of: spammer)
            #expect(verdict.isNotSpam, "\(verdict)")
            clock.advance(by: .seconds(5))
        }
    }

    @Test
    func threeChannelsInTheWindowAreSpam() async throws {
        let clock = ManualClock()
        let cache = SpamCache(clock: clock, runCleanupBackgroundTask: { _ in })
        var verdicts = [SpamCache<ManualClock>.Verdict]()

        for index in 0..<3 {
            let message = makeMessage(id: try .makeFake(), inChannel: index, of: spammer)
            verdicts.append(await cache.recordAndCheck(message, of: spammer))
            clock.advance(by: .seconds(5))
        }

        #expect(verdicts[0].isNotSpam, "\(verdicts[0])")
        #expect(verdicts[1].isNotSpam, "\(verdicts[1])")
        guard case let .spam(entries) = verdicts[2] else {
            Issue.record("Expected the third message to be spam, but got \(verdicts[2])")
            return
        }
        #expect(entries.map(\.channelId) == channels)
    }

    @Test
    func threeChannelsOutsideTheWindowAreNotSpam() async throws {
        let clock = ManualClock()
        let cache = SpamCache(clock: clock, runCleanupBackgroundTask: { _ in })

        for index in 0..<3 {
            let message = makeMessage(id: try .makeFake(), inChannel: index, of: spammer)
            let verdict = await cache.recordAndCheck(message, of: spammer)
            #expect(verdict.isNotSpam, "\(verdict)")
            clock.advance(by: .seconds(45))
        }
    }

    @Test
    func twoChannelsThenAMuchLaterThirdChannelIsNotSpam() async throws {
        let clock = ManualClock()
        let cache = SpamCache(clock: clock, runCleanupBackgroundTask: { _ in })

        for index in 0..<2 {
            let message = makeMessage(id: try .makeFake(), inChannel: index, of: spammer)
            let verdict = await cache.recordAndCheck(message, of: spammer)
            #expect(verdict.isNotSpam, "\(verdict)")
            clock.advance(by: .milliseconds(500))
        }

        clock.advance(by: .seconds(1_000))

        let message = makeMessage(id: try .makeFake(), inChannel: 2, of: spammer)
        let verdict = await cache.recordAndCheck(message, of: spammer)
        #expect(verdict.isNotSpam, "\(verdict)")
    }

    @Test
    func usersAreTrackedSeparately() async throws {
        let clock = ManualClock()
        let cache = SpamCache(clock: clock, runCleanupBackgroundTask: { _ in })
        let otherSpammer: UserSnowflake = "1032312357818151034"
        let innocent: UserSnowflake = "1032312357818151035"

        for index in 0..<3 {
            let spammerVerdict = await cache.recordAndCheck(
                makeMessage(id: try .makeFake(), inChannel: index, of: spammer),
                of: spammer
            )
            let innocentVerdict = await cache.recordAndCheck(
                makeMessage(id: try .makeFake(), inChannel: 0, of: innocent),
                of: innocent
            )
            let otherSpammerVerdict = await cache.recordAndCheck(
                makeMessage(id: try .makeFake(), inChannel: index, of: otherSpammer),
                of: otherSpammer
            )

            if index < 2 {
                #expect(spammerVerdict.isNotSpam, "\(spammerVerdict)")
                #expect(otherSpammerVerdict.isNotSpam, "\(otherSpammerVerdict)")
            } else {
                #expect(!spammerVerdict.isNotSpam, "\(spammerVerdict)")
                #expect(!otherSpammerVerdict.isNotSpam, "\(otherSpammerVerdict)")
            }
            /// The innocent user only ever posts in the same channel, so they are never spam.
            #expect(innocentVerdict.isNotSpam, "\(innocentVerdict)")

            clock.advance(by: .seconds(5))
        }
    }

    /// `DiscordEventListener` handles events concurrently, so a message that was sent earlier
    /// can be handled after one that was sent later.
    @Test
    func outOfOrderMessagesAreStillSpam() async throws {
        let clock = ManualClock()
        let cache = SpamCache(clock: clock, runCleanupBackgroundTask: { _ in })
        var verdicts = [SpamCache<ManualClock>.Verdict]()

        /// Sent 0, 5 and 10 seconds ago, so handled in the reverse order of being sent.
        for index in 0..<3 {
            let message = makeMessage(
                id: try .makeFake(),
                inChannel: index,
                of: spammer,
                sentSecondsAgo: Double(index) * 5
            )
            verdicts.append(await cache.recordAndCheck(message, of: spammer))
        }

        #expect(verdicts[0].isNotSpam, "\(verdicts[0])")
        #expect(verdicts[1].isNotSpam, "\(verdicts[1])")
        guard case let .spam(entries) = verdicts[2] else {
            Issue.record("Expected the third message to be spam, but got \(verdicts[2])")
            return
        }
        #expect(entries.map(\.channelId) == channels)
    }

    @Test
    func anOutOfOrderMessageDoesNotReplaceANewerOneOfTheSameChannel() async throws {
        let clock = ManualClock()
        let cache = SpamCache(clock: clock, runCleanupBackgroundTask: { _ in })
        let newest: MessageSnowflake = "1039637770005717099"

        _ = await cache.recordAndCheck(makeMessage(id: newest, inChannel: 0, of: spammer), of: spammer)
        _ = await cache.recordAndCheck(
            makeMessage(id: try .makeFake(), inChannel: 0, of: spammer, sentSecondsAgo: 10),
            of: spammer
        )
        _ = await cache.recordAndCheck(makeMessage(id: try .makeFake(), inChannel: 1, of: spammer), of: spammer)
        let verdict = await cache.recordAndCheck(
            makeMessage(id: try .makeFake(), inChannel: 2, of: spammer),
            of: spammer
        )

        guard case let .spam(entries) = verdict else {
            Issue.record("Expected the fourth message to be spam, but got \(verdict)")
            return
        }
        #expect(entries.first(where: { $0.channelId == channels[0] })?.messageId == newest)
    }

    /// Discord replays buffered events all at once after a gateway resume,
    /// so the clock does not move at all here.
    @Test
    func replayedMessagesAreNotSpam() async throws {
        let clock = ManualClock()
        let cache = SpamCache(clock: clock, runCleanupBackgroundTask: { _ in })

        for index in 0..<3 {
            let message = makeMessage(
                id: try .makeFake(),
                inChannel: index,
                of: spammer,
                sentSecondsAgo: Double(index) * 120
            )
            let verdict = await cache.recordAndCheck(message, of: spammer)
            #expect(verdict.isNotSpam, "\(verdict)")
        }
    }

    @Test
    func messagesInTheGracePeriodAfterAFlagAreAlreadyFlagged() async throws {
        let clock = ManualClock()
        let cache = SpamCache(clock: clock, runCleanupBackgroundTask: { _ in })

        for index in 0..<3 {
            let message = makeMessage(id: try .makeFake(), inChannel: index, of: spammer)
            _ = await cache.recordAndCheck(message, of: spammer)
        }

        clock.advance(by: .seconds(1))
        let message1 = makeMessage(id: try .makeFake(), inChannel: 0, of: spammer)
        let inGracePeriod = await cache.recordAndCheck(message1, of: spammer)
        guard case .alreadyFlagged = inGracePeriod else {
            Issue.record("Expected the message to be already-flagged, but got \(inGracePeriod)")
            return
        }

        clock.advance(by: SpamCache<ManualClock>.flagDuration)
        let message2 = makeMessage(id: try .makeFake(), inChannel: 0, of: spammer)
        let afterGracePeriod = await cache.recordAndCheck(message2, of: spammer)
        #expect(afterGracePeriod.isNotSpam, "\(afterGracePeriod)")
    }
}

extension SpamCache.Verdict {
    fileprivate var isNotSpam: Bool {
        if case .notSpam = self {
            return true
        } else {
            return false
        }
    }
}
