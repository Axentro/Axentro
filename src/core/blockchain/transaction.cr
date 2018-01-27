module ::Sushi::Core
  class Transaction
    MESSAGE_SIZE_LIMIT = 512
    ACTIONS = %(send)

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
      sha256(string).hexstring
    end

    def valid?(blockchain : Blockchain, block_index : Int64, is_coinbase : Bool) : Bool
      raise "Length of transaction id have to be 64: #{@id}" if @id.size != 64
      raise "Message size exceeds: #{self.message.bytesize} for #{MESSAGE_SIZE_LIMIT}" if self.message.bytesize > MESSAGE_SIZE_LIMIT

      @senders.each do |sender|
        raise "Invalid checksum for sender's address: #{sender[:address]}" unless Wallet.valid_checksum?(sender[:address])
      end

      @recipients.each do |recipient|
        raise "Invalid checksum for recipient's address: #{recipient[:address]}" unless Wallet.valid_checksum?(recipient[:address])
      end

      if !is_coinbase
        raise "Unknown action: #{@action}" unless ACTIONS.includes?(@action)
        raise "Sender have to be only one currently" if @senders.size != 1

        secp256k1  = ECDSA::Secp256k1.new
        public_key = ECDSA::Point.new(
          secp256k1,
          BigInt.new(Base64.decode_string(@senders[0][:px]), base: 10),
          BigInt.new(Base64.decode_string(@senders[0][:py]), base: 10),
        )

        raise "Invalid signing" if !secp256k1.verify(
                                     public_key,
                                     self.as_unsigned.to_hash,
                                     BigInt.new(@sign_r, base: 16),
                                     BigInt.new(@sign_s, base: 16),
                                   )

        if calculate_fee < min_fee_of_action(@action)
          raise "Not enough fee, should be  #{calculate_fee} >= #{min_fee_of_action(@action)}"
        end

        senders_amount = blockchain.get_amount_unconfirmed(@senders[0][:address])

        if prec(senders_amount - @senders[0][:amount]) < 0.0
          raise "Sender has not enough coins: #{@senders[0][:address]} (#{senders_amount})"
        end
      else
        raise "actions has to be 'head' for coinbase transaction " if @action != "head"
        raise "message has to be '0' for coinbase transaction" if @message != "0"
        raise "there should be no Sender for a coinbase transaction" if @senders.size != 0
        raise "prev_hash of coinbase transaction has to be '0'" if @prev_hash != "0"
        raise "sign_r of coinbase transaction has to be '0'" if @sign_r != "0"
        raise "sign_s of coinbase transaction has to be '0'" if @sign_s != "0"

        served_sum = @recipients.reduce(0.0) { |sum, recipient| prec(sum + recipient[:amount]) }
        raise "Invalid served amount for coinbase transaction: #{served_sum}" if served_sum != Blockchain.served_amount(block_index)
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

    def sender_total_amount : Float64
      senders.reduce(0.0) { |sum, sender| prec(sum + sender[:amount]) }
    end

    def recipient_total_amount : Float64
      recipients.reduce(0.0) { |sum, recipient| prec(sum + recipient[:amount]) }
    end

    def calculate_fee : Float64
      prec(sender_total_amount - recipient_total_amount)
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
