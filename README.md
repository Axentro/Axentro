<p align="center">
  <img src="https://raw.githubusercontent.com/SushiChain/SushiChain/master/imgs/sushichain.png" width="150" height="150" />
</p1>

<p align="center">🍣 <i>An awesome developable blockchain implementation.</i> 🍣</p>

<p align="center"><a href="https://circleci.com/gh/SushiChain/SushiChain/tree/master"><img src="https://circleci.com/gh/SushiChain/SushiChain/tree/master.png?circle-token=099c1a2ed8be9aebf10eb09f79d65dfa4b05cf8e"></a>
<a href="https://sushicoin.xyz/viewType.html?buildTypeId=SushiChain_1MainBuild&guest=1">
<img src="https://sushicoin.xyz/app/rest/builds/buildType:(id:SushiChain_1MainBuild)/statusIcon"/></a>
<a href="https://bit.ly/2HJBu1z"><img src="https://img.shields.io/badge/chat-slack-brightgreen.svg"></a>
<a href="https://discord.gg/qBqfJPv"><img src="https://img.shields.io/discord/441519469810941953.svg"></a>
<a href="https://gitter.im/SushiChain/Lobby"><img src="https://img.shields.io/gitter/room/nwjs/nw.js.svg"></a>
<a href="https://t.me/joinchat/Inebcg83C4ccxydPkzTdSw"><img src="https://img.shields.io/badge/chat-telegram-brightgreen.svg"></a>
<a href="https://github.com/SushiChain/SushiChain/wiki"><img src="https://img.shields.io/badge/document-wiki-yellow.svg"></a></p>

## Document

All documents are written on [wiki](https://github.com/SushiChain/SushiChain/wiki)

* [What is SushiChain?](https://github.com/SushiChain/SushiChain/wiki/What-is-SushiChain%3F)
* [How to build SushiChain?](https://github.com/SushiChain/SushiChain/wiki/How-to-build-SushiChain%3F)
* [QuickStart guide!](https://github.com/SushiChain/SushiChain/wiki/SushiChain-QuickStart)
* [I want to do mining on SushiChain!](https://github.com/SushiChain/SushiChain/wiki/Mining-SushiChain)
* [I want to build a SushiChain node!](https://github.com/SushiChain/SushiChain/wiki/Build-a-SushiChain-node)

## Communities

We are discussing many things everyday in [Slack](https://bit.ly/2HJBu1z), [Discord](https://discord.gg/qBqfJPv), [Gitter](https://gitter.im/SushiChain/Lobby) and [Telegram](https://t.me/joinchat/Inebcg83C4ccxydPkzTdSw).

These channels are bridged each other.

🍣 We are welcome your joining! 🍣

## Contributors
- [@tbrand](https://github.com/tbrand) Taichiro Suzuki - core developer, founder
- [@kingsleyh](https://github.com/kingsleyh) Kingsley Hendrickse - core developer, co-creator

# Memo
tranasction validation
 - blockchain.align_transactions
 - block.valid_as_latest?

## Check
- [ ] Validate a transaction in block
- [ ] Validate a transaction in prev blocks
- [ ] Transaction's validation should not be passed blockchain
  - [ ] All data is recorded into database as structured data
