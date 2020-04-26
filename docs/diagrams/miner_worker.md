sequenceDiagram
	Miner -->> Message Bus: subscribe to  nonces
    Miner ->> Message Bus: publish instructions
    Worker1 -->> Message Bus: subscribe to instructions
    Worker1 ->> Message Bus: publish nonce
    Worker2 -->> Message Bus: subscribe to instructions
    Worker2 ->> Message Bus: publish nonce