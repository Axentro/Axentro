# Garnet

Blockchain implementation witten in Crystal.

- Still under **Super Work In Progress**.
- NOT safety and NOT stable.
- Has no compatible with Bitcoin.

## Short Usage

Details will be updated soon, I had no time to write it...

0. Build garnet
1. Create your wallet
2. Launch your node
3. Start mining! :rocket:

### Build
```bash
> shards build
```

### Create a wallet
```bash
./bin/garnet wallet create -w path_to_the_wallet.json
```

### Launch a node
```bash
# Command line
> ./bin/garnetd start -n "http://[your host]:[your port]" -w your_wallet.json -c "[connecting node]"

# For example (Connecting node is omitted, so it is standalone node)
> ./bin/garnetd start -n "http://localhost:3000" -w path_to_the_wallet.json
```

### Start mining process
```bash
> ./bin/garnetm start -w path_to_the_wallet.json -n http://localhost:3000
```
