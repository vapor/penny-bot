# <img src="https://github.com/vapor/penny-bot/assets/54685446/53e4684e-7511-4a5e-9933-34db0ceac0c6" alt="Penny" width="32"> Penny

Penny is a Swift bot that works for the [Vapor](https://vapor.codes) community.

[![Team Chat](https://design.vapor.codes/images/discordchat.svg)](https://discord.gg/vapor)
[![Tests CI](https://img.shields.io/github/actions/workflow/status/vapor/penny-bot/test.yml?event=push&style=plastic&logo=github&label=tests&logoColor=ccc)](https://github.com/vapor/penny-bot/actions/workflows/test.yml)
[![Deploy Lambdas CI](https://img.shields.io/github/actions/workflow/status/vapor/penny-bot/deploy-all-lambdas.yml?event=push&style=plastic&logo=github&label=deploy%20lambda%20functions&logoColor=ccc)](https://github.com/vapor/penny-bot/actions/workflows/deploy-all-lambdas.yml)
[![Deploy Penny CI](https://img.shields.io/github/actions/workflow/status/vapor/penny-bot/deploy-penny.yml?event=push&style=plastic&logo=github&label=deploy%20Penny&logoColor=ccc)](https://github.com/vapor/penny-bot/actions/workflows/deploy-penny.yml)
[![Swift 6.3+](https://design.vapor.codes/images/swift63up.svg)](https://swift.org)

</div>

### Features
* [x] Give coins to the members when they're "thanked".
* [x] Automatically ping members based on the ping-words they have set up.
  * Implemented as `/auto-pings` slash command.
* [x] Respond to certain command-texts with predefined answers.
  * Implemented as `/faqs` slash command.
* [x] Automatically respond to commonly asked questions.
  * Implemented as `/auto-faqs` slash command.
* [x] Automate SemVer releases and report on Discord.
* [x] Report GitHub PRs and Issues on Discord.
* [x] Report Swift evolution proposals on Discord.
* [x] Report Swift releases on Discord.
* [x] Report StackOverflow questions on Discord.
* [x] Connect members' Discord & GitHub accounts for better integrations.
* [x] Thank members when they contribute to Vapor repositories.
* [ ] Manage sponsor/backer status of GitHub users.

### Automatic Releases

Penny detects usage of specific labels in PRs and tries to act accordingly and automatically tag a new release when an applicable PR is merged.

The related labels are:
* `semver-patch`
* `semver-minor`
* `semver-major`
* `semver-noop`
* `release`
* `prerelease`
* `no-release-needed`

Some other notes:
* `semver-major` and `release` are of limited use for automatic releases. Penny won't do a whole major release by itself since those are rare and they can be risky to do.
* Use `prerelease` label in combination with another semver label like `semver-patch` to make sure Penny can correctly create a prerelease, when a prerelease is needed.
  * For example when you have a `v5.0.0-alpha.1` release and want Penny to tag `v5.0.0-alpha.2` next.
* Try to use `no-release-needed` or `semver-noop` when no release is needed.
