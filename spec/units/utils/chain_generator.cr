# Copyright © 2017-2018 The SushiChain Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the SushiChain Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

module ::Units::Utils::ChainGenerator
  include Sushi::Core
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
    @miner : NodeComponents::MinersManager::Miner
    property node_wallet : Wallet
    property miner_wallet : Wallet
    property transaction_factory : TransactionFactory
    property blockchain : Blockchain
    property node : Sushi::Core::Node

    def initialize
      @node_wallet = Wallet.from_json(Wallet.create(true).to_json)
      @miner_wallet = Wallet.from_json(Wallet.create(true).to_json)
      @node = Sushi::Core::Node.new(true, true, "bind_host", 8008_i32, nil, nil, nil, nil, nil, @node_wallet, nil, 1_i32, false)
      @blockchain = Blockchain.new(node_wallet)
      @blockchain.setup(@node)
      @miner = {address: miner_wallet.address, socket: MockWebSocket.new, nonces: [] of UInt64}
      @transaction_factory = TransactionFactory.new(@node_wallet)
      enable_ut
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
      remove_ut
      @blockchain.chain
    end

    def sub_chain
      @blockchain.chain.reject! { |b| b.prev_hash == "genesis" }
    end

    def remove_ut
      ENV.delete("UT")
    end

    def enable_ut
      ENV["UT"] = "unit tests"
    end
  end

  class TransactionFactory
    property recipient_wallet : Wallet
    property sender_wallet : Wallet

    def initialize(sender_wallet : Wallet)
      @sender_wallet = sender_wallet
      @recipient_wallet = Wallet.from_json(Wallet.create(true).to_json)
    end

    def make_send(sender_amount : Int64, token : String = TOKEN_DEFAULT, sender_wallet : Wallet = @sender_wallet, recipient_wallet : Wallet = @recipient_wallet) : Transaction
      transaction_id = Transaction.create_id
      unsigned_transaction = Transaction.new(
        transaction_id,
        "send", # action
        [a_sender(sender_wallet, sender_amount)],
        [a_recipient(recipient_wallet, sender_amount)],
        "0",   # message
        token, # token
        "0",   # prev_hash
        "0",   # sign_r
        "0",   # sign_s
      )
      signature = sign(sender_wallet, unsigned_transaction)
      unsigned_transaction.signed(signature[:r], signature[:s])
    end

    def align_transaction(transaction : Transaction, prev_hash : String) : Transaction
      transaction.prev_hash = prev_hash
      transaction
    end

    def make_send_with_prev_hash(sender_amount : Int64, prev_hash : String, sender_wallet : Wallet = @sender_wallet, recipient_wallet : Wallet = @recipient_wallet) : Transaction
      transaction_id = Transaction.create_id
      unsigned_transaction = Transaction.new(
        transaction_id,
        "send", # action
        [a_sender(sender_wallet, sender_amount)],
        [a_recipient(recipient_wallet, sender_amount)],
        "0",           # message
        TOKEN_DEFAULT, # token
        prev_hash,     # prev_hash
        "0",           # sign_r
        "0",           # sign_s
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
        [] of Transaction::Recipient,
        domain,        # message
        TOKEN_DEFAULT, # token
        "0",           # prev_hash
        "0",           # sign_r
        "0",           # sign_s
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
        domain,        # message
        TOKEN_DEFAULT, # token
        "0",           # prev_hash
        "0",           # sign_r
        "0",           # sign_s
      )
      signature = sign(sender_wallet, unsigned_transaction)
      unsigned_transaction.signed(signature[:r], signature[:s])
    end

    def make_buy_domain_from_seller(domain : String, recipient_amount : Int64, recipients : Array(Transaction::Recipient)) : Transaction
      transaction_id = Transaction.create_id
      unsigned_transaction = Transaction.new(
        transaction_id,
        "scars_buy", # action
        [a_sender(recipient_wallet, recipient_amount, 100_i64)],
        recipients,
        domain,        # message
        TOKEN_DEFAULT, # token
        "0",           # prev_hash
        "0",           # sign_r
        "0",           # sign_s
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
        domain,        # message
        TOKEN_DEFAULT, # token
        "0",           # prev_hash
        "0",           # sign_r
        "0",           # sign_s
      )
      signature = sign(sender_wallet, unsigned_transaction)
      unsigned_transaction.signed(signature[:r], signature[:s])
    end

    def make_sell_domain(domain : String, sender_amount : Int64, recipients : Array(Transaction::Recipient), sender_wallet : Wallet = @sender_wallet) : Transaction
      transaction_id = Transaction.create_id
      unsigned_transaction = Transaction.new(
        transaction_id,
        "scars_sell", # action
        [a_sender(sender_wallet, sender_amount, 100_i64)],
        recipients,
        domain,        # message
        TOKEN_DEFAULT, # token
        "0",           # prev_hash
        "0",           # sign_r
        "0",           # sign_s
      )
      signature = sign(sender_wallet, unsigned_transaction)
      unsigned_transaction.signed(signature[:r], signature[:s])
    end

    def make_cancel_domain(domain : String, sender_amount : Int64, sender_wallet : Wallet = @sender_wallet) : Transaction
      transaction_id = Transaction.create_id
      unsigned_transaction = Transaction.new(
        transaction_id,
        "scars_cancel", # action
        [a_sender(sender_wallet, sender_amount, 100_i64)],
        [a_recipient(sender_wallet, sender_amount)],
        domain,        # message
        TOKEN_DEFAULT, # token
        "0",           # prev_hash
        "0",           # sign_r
        "0",           # sign_s
      )
      signature = sign(sender_wallet, unsigned_transaction)
      unsigned_transaction.signed(signature[:r], signature[:s])
    end

    def make_cancel_domain(domain : String, sender_amount : Int64, recipients : Array(Transaction::Recipient), sender_wallet : Wallet = @sender_wallet) : Transaction
      transaction_id = Transaction.create_id
      unsigned_transaction = Transaction.new(
        transaction_id,
        "scars_cancel", # action
        [a_sender(sender_wallet, sender_amount, 100_i64)],
        recipients,
        domain,        # message
        TOKEN_DEFAULT, # token
        "0",           # prev_hash
        "0",           # sign_r
        "0",           # sign_s
      )
      signature = sign(sender_wallet, unsigned_transaction)
      unsigned_transaction.signed(signature[:r], signature[:s])
    end

    def make_create_token(token : String, sender_amount : Int64, sender_wallet : Wallet = @sender_wallet, recipient_wallet : Wallet = @recipient_wallet) : Transaction
      transaction_id = Transaction.create_id
      unsigned_transaction = Transaction.new(
        transaction_id,
        "create_token", # action
        [a_sender(sender_wallet, sender_amount, 1000_i64)],
        [a_recipient(sender_wallet, sender_amount)],
        "0",   # message
        token, # token
        "0",   # prev_hash
        "0",   # sign_r
        "0",   # sign_s
      )
      signature = sign(sender_wallet, unsigned_transaction)
      unsigned_transaction.signed(signature[:r], signature[:s])
    end

    def make_create_token(token : String, senders : Array(Transaction::Sender), recipients : Array(Transaction::Recipient)) : Transaction
      transaction_id = Transaction.create_id
      unsigned_transaction = Transaction.new(
        transaction_id,
        "create_token", # action
        senders,
        recipients,
        "0",   # message
        token, # token
        "0",   # prev_hash
        "0",   # sign_r
        "0",   # sign_s
      )
      signature = sign(sender_wallet, unsigned_transaction)
      unsigned_transaction.signed(signature[:r], signature[:s])
    end
  end
end
