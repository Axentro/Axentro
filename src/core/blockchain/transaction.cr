module ::Sushi::Core
  class Transaction
    MESSAGE_SIZE_LIMIT = 512

    JSON.mapping(
      id: String,
      action: String,
      senders: Models::Senders,
      recipients: Models::Recipients,
      message: String,
      prev_hash: String,
      sign_r: String,
      sign_s: String,
    )

    setter prev_hash : String

    def initialize(
      @id : String,
      @action : String,
      @senders : Models::Senders,
      @recipients : Models::Recipients,
      @message : String,
      @prev_hash : String,
      @sign_r : String,
      @sign_s : String
    )
    end

    def self.create_id : String
      tmp_id = Random::Secure.hex(32)
      return create_id if tmp_id[0] == "0"
      tmp_id
    end

    def to_hash : String
      string = self.to_json
      sha256(string)
    end

    def valid?(blockchain : Blockchain, block_index : Int64, is_coinbase : Bool, transactions : Array(Transaction)) : Bool
      raise "length of transaction id have to be 64: #{@id}" if @id.size != 64
      raise "message size exceeds: #{self.message.bytesize} for #{MESSAGE_SIZE_LIMIT}" if self.message.bytesize > MESSAGE_SIZE_LIMIT

      @senders.each do |sender|
        raise "invalid checksum for sender's address: #{sender[:address]}" unless Keys::Address.from(sender[:address], "sender")
      end

      @recipients.each do |recipient|
        raise "invalid checksum for recipient's address: #{recipient[:address]}" unless Keys::Address.from(recipient[:address], "recipient")
      end

      if !is_coinbase
        raise "unknown action: #{@action}" unless blockchain.available_actions.includes?(@action)
        raise "sender have to be only one currently" if @senders.size != 1
        raise "There must be some transactions" if transactions.size < 1

        if @prev_hash != transactions[-1].to_hash
          raise "invalid prev_hash #{@prev_hash} vs #{transactions[-1].to_hash}"
        end

        if blockchain.indices.get(@id)
          raise "the transaction #{@id} is already included in #{blockchain.indices.get(@id)}"
        end

        network = Keys::Address.from(@senders.first[:address]).network
        public_key = Keys::PublicKey.new(@senders.first[:public_key], network)

        secp256k1 = ECDSA::Secp256k1.new

        raise "invalid signing" if !secp256k1.verify(
                                     public_key.point,
                                     self.as_unsigned.to_hash,
                                     BigInt.new(@sign_r, base: 16),
                                     BigInt.new(@sign_s, base: 16),
                                   )

        blockchain.dapps.each do |dapp|
          dapp.valid?(self, transactions) if dapp.related?(@action)
        end
      else
        raise "actions has to be 'head' for coinbase transaction " if @action != "head"
        raise "message has to be '0' for coinbase transaction" if @message != "0"
        raise "there should be no Sender for a coinbase transaction" if @senders.size != 0
        raise "prev_hash of coinbase transaction has to be '0'" if @prev_hash != "0"
        raise "sign_r of coinbase transaction has to be '0'" if @sign_r != "0"
        raise "sign_s of coinbase transaction has to be '0'" if @sign_s != "0"

        served_sum = @recipients.reduce(0_i64) { |sum, recipient| sum + recipient[:amount] }
        raise "invalid served amount for coinbase transaction: #{served_sum}" if served_sum != blockchain.served_amount(block_index)
      end

      true
    end

    def signed(sign_r : String, sign_s : String)
      Transaction.new(
        self.id,
        self.action,
        self.senders,
        self.recipients,
        self.message,
        self.prev_hash,
        sign_r,
        sign_s,
      )
    end

    def as_unsigned : Transaction
      Transaction.new(
        self.id,
        self.action,
        self.senders,
        self.recipients,
        self.message,
        "0",
        "0",
        "0",
      )
    end

    def sender_total_amount : Int64
      senders.reduce(0_i64) { |sum, sender| sum + sender[:amount] }
    end

    def recipient_total_amount : Int64
      recipients.reduce(0_i64) { |sum, recipient| sum + recipient[:amount] }
    end

    def calculate_fee : Int64
      senders.reduce(0_i64) { |sum, sender| sum + sender[:fee] }
    end

    include Hashes
  end
end
