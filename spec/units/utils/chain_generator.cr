module ::Units::Utils::ChainGenerator
  include Sushi::Core
  include Sushi::Core::Models
  include Sushi::Core::Keys

  def with_factory(&block)
    block_factory = BlockFactory.new
    yield block_factory, block_factory.transaction_factory
  end

  class MockWebSocket < HTTP::WebSocket
    def initialize
      super(IO::Memory.new)
    end
  end

  class BlockFactory
    @miner : Miner
    property node_wallet : Wallet
    property miner_wallet : Wallet
    property transaction_factory : TransactionFactory

    def initialize
      @node_wallet = Wallet.from_json(Wallet.create(true).to_json)
      @miner_wallet = Wallet.from_json(Wallet.create(true).to_json)
      @blockchain = Blockchain.new(node_wallet)
      @miner = {address: miner_wallet.address, socket: MockWebSocket.new, nonces: [] of UInt64}
      @transaction_factory = TransactionFactory.new(@node_wallet)
      ENV["UT"] = "unit test"
    end

    def addBlock
      @blockchain.push_block?(1_u64, [@miner])
      self
    end

    def addBlocks(number : Int)
      (1..number).each { |_| addBlock }
      self
    end

    def addBlock(transactions : Array(Transaction))
      transactions.each { |txn| @blockchain.add_transaction(txn) }
      @blockchain.push_block?(1_u64, [@miner])
      self
    end

    def chain
      @blockchain.chain
    end
  end

  class TransactionFactory
    property recipient_wallet : Wallet
    property sender_wallet : Wallet

    def initialize(sender_wallet : Wallet)
      @sender_wallet = sender_wallet
      @recipient_wallet = Wallet.from_json(Wallet.create(true).to_json)
    end

    def make_send(sender_amount : Int64, sender_wallet : Wallet = @sender_wallet, recipient_wallet : Wallet = @recipient_wallet) : Transaction
      transaction_id = Transaction.create_id
      unsigned_transaction = Transaction.new(
        transaction_id,
        "send", # action
        [a_sender(sender_wallet, sender_amount)],
        [a_recipient(recipient_wallet, sender_amount)],
        "0", # message
        "0", # prev_hash
        "0", # sign_r
        "0", # sign_s
      )
      signature = sign(sender_wallet, unsigned_transaction)
      unsigned_transaction.signed(signature[:r], signature[:s])
    end

    def make_buy_domain_from_platform(domain : String, sender_amount : Int64, sender_wallet : Wallet = @sender_wallet) : Transaction
      transaction_id = Transaction.create_id
      unsigned_transaction = Transaction.new(
        transaction_id,
        "scars_buy", # action
        [a_sender(sender_wallet, sender_amount, 100_i64)],
        [] of Recipient,
        domain, # message
        "0",    # prev_hash
        "0",    # sign_r
        "0",    # sign_s
      )
      signature = sign(sender_wallet, unsigned_transaction)
      unsigned_transaction.signed(signature[:r], signature[:s])
    end

    def make_buy_domain_from_seller(domain : String, recipient_amount : Int64, recipient_wallet : Wallet = @recipient_wallet) : Transaction
      transaction_id = Transaction.create_id
      unsigned_transaction = Transaction.new(
        transaction_id,
        "scars_buy", # action
        [a_sender(recipient_wallet, recipient_amount, 100_i64)],
        [a_recipient(@sender_wallet, 100_i64)],
        domain, # message
        "0", # prev_hash
        "0", # sign_r
        "0", # sign_s
      )
      signature = sign(sender_wallet, unsigned_transaction)
      unsigned_transaction.signed(signature[:r], signature[:s])
    end

    def make_buy_domain_from_seller(domain : String, recipient_amount : Int64, recipients : Array(Recipient)) : Transaction
      transaction_id = Transaction.create_id
      unsigned_transaction = Transaction.new(
        transaction_id,
        "scars_buy", # action
        [a_sender(recipient_wallet, recipient_amount, 100_i64)],
        recipients,
        domain, # message
        "0", # prev_hash
        "0", # sign_r
        "0", # sign_s
      )
      signature = sign(sender_wallet, unsigned_transaction)
      unsigned_transaction.signed(signature[:r], signature[:s])
    end

    def make_sell_domain(domain : String, sender_amount : Int64, sender_wallet : Wallet = @sender_wallet) : Transaction
      transaction_id = Transaction.create_id
      unsigned_transaction = Transaction.new(
        transaction_id,
        "scars_sell", # action
        [a_sender(sender_wallet, sender_amount, 100_i64)],
        [a_recipient(sender_wallet, sender_amount)],
        domain, # message
        "0", # prev_hash
        "0", # sign_r
        "0", # sign_s
      )
      signature = sign(sender_wallet, unsigned_transaction)
      unsigned_transaction.signed(signature[:r], signature[:s])
    end

    def make_sell_domain(domain : String, sender_amount : Int64, recipients : Array(Recipient), sender_wallet : Wallet = @sender_wallet) : Transaction
      transaction_id = Transaction.create_id
      unsigned_transaction = Transaction.new(
        transaction_id,
        "scars_sell", # action
        [a_sender(sender_wallet, sender_amount, 100_i64)],
        recipients,
        domain, # message
        "0", # prev_hash
        "0", # sign_r
        "0", # sign_s
      )
      signature = sign(sender_wallet, unsigned_transaction)
      unsigned_transaction.signed(signature[:r], signature[:s])
    end

  end
end
