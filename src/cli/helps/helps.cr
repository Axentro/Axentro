module ::Sushi::Interface
  module Helps
    HELP_WALLET_PATH                      = "please specify your wallet: -w [your_wallet.json]"
    HELP_WALLET_PATH_OR_ADDRESS_OR_DOMAIN = "please specify a wallet or an address: -w [your_wallet.json], -a [public_address] or --domain=[some_domain]"
    HELP_WALLET_ALREADY_EXISTS            = "the wallet at %s already exists, specify another path"
    HELP_WALLET_PASSWORD                  = "please specify the password for this wallet"
    HELP_ADDRESS_DOMAIN_RECIPIENT         = "please specify a recipient's address or domain: -a [public address] or --domain=[domain]"
    HELP_AMOUNT                           = "please specify sending amount: -m [amount]"
    HELP_CONNECTING_NODE                  = "please specify a connecting node: -n http://[host]:[port]"
    HELP_BLOCK_INDEX_OR_ADDRESS           = "please specify a block index or an address: -i [block index] or -a [address]"
    HELP_BLOCK_INDEX_OR_TRANSACTION_ID    = "please specify a block index or transaction id: -i [block index] or -t [transaction id]"
    HELP_TRANSACTION_ID                   = "please specify a transaction id: -t [transaction id]"
    HELP_PUBLIC_URL                       = "please specify a public url that can be accessed from internet: -u http://[host]:[port]. If your node is behind a NET, you can use --private flag instread of this option"
    HELP_FEE                              = "please specify transaction fee: -f [fee]. you can check minimum fee by `sushi tx fees`"
    HELP_PRICE                            = "please specify a price for scars --price=[PRICE]"
    HELP_DOMAIN                           = "please specify a domain for scars: --domain=[DOMAIN]"
  end
end
