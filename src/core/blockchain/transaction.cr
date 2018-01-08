module ::Garnet::Core
  class Transaction
    JSON.mapping(
      id: String,
      action: String,
      senders: Models::Senders,
      recipients: Models::Recipients,
      prev_hash: String,
      content_hash: String,
      sign_r: String,
      sign_s: String,
    )

    setter prev_hash : String

    def initialize(
          @id : String,
          @action : String,
          @senders : Models::Senders,
          @recipients : Models::Recipients,
          @prev_hash : String,
          @content_hash : String,
          @sign_r : String,
          @sign_s : String,
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

    def valid?(blockchain : Blockchain, block_index : UInt32, is_coinbase : Bool) : Bool
      return false if @id.size != 64

      @senders.each do |sender|
        return false unless Wallet.valid_checksum?(sender[:address])
      end

      @recipients.each do |recipient|
        return false unless Wallet.valid_checksum?(recipient[:address])
      end

      if !is_coinbase
        return false if @senders.size != 1

        secp256k1  = ECDSA::Secp256k1.new
        public_key = ECDSA::Point.new(
          secp256k1,
          BigInt.new(Base64.decode_string(@senders[0][:px]), base: 10),
          BigInt.new(Base64.decode_string(@senders[0][:py]), base: 10),
        )

        return false if !secp256k1.verify(
                          public_key,
                          self.as_unsigned.to_hash,
                          BigInt.new(@sign_r, base: 16),
                          BigInt.new(@sign_s, base: 16),
                        )

        return false if calculate_fee < min_fee_of_action(@action)
        return false if prec(
                          blockchain.get_amount_unconfirmed(@senders[0][:address]) -
                          @senders[0][:amount]
                        ) < 0.0
      else
        return false if @action != "head"
        return false if @senders.size != 0
        return false if @prev_hash != "0"
        return false if @content_hash != "0"
        return false if @sign_r != "0"
        return false if @sign_s != "0"

        served_sum = @recipients.reduce(0.0) { |sum, recipient| prec(sum + recipient[:amount]) }
        return false if served_sum != Blockchain.served_amount(block_index)
      end

      true
    end
    def signed(sign_r : String, sign_s : String)
      Transaction.new(
        self.id,
        self.action,
        self.senders,
        self.recipients,
        self.prev_hash,
        self.content_hash,
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
        "0",
        self.content_hash,
        "0",
        "0",
      )
    end

    def sender_total_amounts : Float64
      senders.reduce(0.0) { |sum, sender| prec(sum + sender[:amount]) }
    end

    def recipient_total_amounts : Float64
      recipients.reduce(0.0) { |sum, recipient| prec(sum + recipient[:amount]) }
    end

    def calculate_fee : Float64
      prec(sender_total_amounts - recipient_total_amounts)
    end

    def calculate_utxo : Hash(String, Float64)
      utxo = Hash(String, Float64).new

      senders.each do |sender|
        utxo[sender[:address]] ||= 0.0
        utxo[sender[:address]] = prec(utxo[sender[:address]] - sender[:amount])
      end

      recipients.each do |recipient|
        utxo[recipient[:address]] ||= 0.0
        utxo[recipient[:address]] = prec(utxo[recipient[:address]] + recipient[:amount])
      end

      utxo
    end

    include Fees
    include Hashes
    include Common::Num
  end
end
