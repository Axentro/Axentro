module ::Sushi::Interface
  module Helps
    HELP_WALLET_PATH                   = "Please specify your wallet: -w [your_wallet.json]"
    HELP_WALLET_PATH_OR_ADDRESS        = "Please specify a wallet or an address: -w [your_wallet.json] or -a [public_address]"
    HELP_WALLET_ALREADY_EXISTS         = "The wallet at %s already exists, specify another path"
    HELP_WALLET_PASSWORD               = "Please specify the password for this wallet"
    HELP_ADDRESS_RECIPIENT             = "Please specify a recipient's address: -a [public address]"
    HELP_AMOUNT                        = "Please specify sending amount: -m [amount]"
    HELP_CONNECTING_NODE               = "Please specify a connecting node: -n http://[host]:[port]"
    HELP_BLOCK_INDEX                   = "Please specify a block index: -i [block index]"
    HELP_BLOCK_INDEX_OR_TRANSACTION_ID = "Please specify a block index or transaction id: -i [block index] or -t [transaction id]"
    HELP_TRANSACTION_ID                = "Please specify a transaction id: -t [transaction id]"
    HELP_PUBLIC_URL                    = "Please specify a public url that can be accessed from internet: -u http://[host]:[port]\nIf your node is behind a NET, you can use --private flag instread of this option"
  end
end
