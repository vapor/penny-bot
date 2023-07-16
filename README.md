# <img src="https://github.com/vapor/penny-bot/assets/54685446/53e4684e-7511-4a5e-9933-34db0ceac0c6" alt="Penny" width="32"> Penny

Penny is a Swift bot that works for the [Vapor](https://vapor.codes) community.

<p>
    <a href="https://discord.gg/vapor">
        <img src="https://img.shields.io/discord/431917998102675485.svg" alt="Team Chat">
    </a>
    <a href="https://github.com/vapor/vapor/actions/workflows/test.yml">
        <img src="https://github.com/vapor/penny-bot/actions/workflows/test.yml/badge.svg?branch=main" alt="Tests CI">
    </a>
    <a href="https://github.com/vapor/penny-bot/actions/workflows/deploy-all-lambdas.yml">
        <img src="https://github.com/vapor/penny-bot/actions/workflows/deploy-all-lambdas.yml/badge.svg?branch=main" alt="Deploy Lambdas CI">
    </a>
    <a href="https://github.com/vapor/penny-bot/actions/workflows/deploy-penny.yml">
        <img src="https://github.com/vapor/penny-bot/actions/workflows/deploy-penny.yml/badge.svg?branch=main" alt="Deploy Penny CI">
    </a>
    <a href="https://swift.org">
        <img src="https://img.shields.io/badge/swift-5.8-brightgreen.svg" alt="Swift 5.8">
    </a>
</p>

### Features
* [x] Give coins to the members when they're "thanked".
* [x] Automatically ping members based on the ping-words they have set up.
  * Implemented as `/auto-pings` slash command. 
* [x] Respond to certain command-texts with predefined answers.
  * Implemented as `/faqs` slash command.
* [ ] Automatically respond to commonly asked questions.
* [x] Automate SemVer releases and report on Discord.
* [x] Report GitHub PRs and Issues on Discord.
* [ ] Manage sponsor/backer status of GitHub users.
* [ ] Connect members' Discord & GitHub accounts for better integrations.
* [ ] Thank members when they contribute to Vapor repositories.
