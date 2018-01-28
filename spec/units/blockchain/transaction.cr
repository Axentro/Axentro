require "./../../spec_helper"
require "./../utils"

include Sushi::Core::Models
include Units::Utils
include Sushi::Core
include Hashes

describe Transaction do

  it "should create a transaction id of length 64" do
    Transaction.create_id.size.should eq(64)
  end

  it "should create a new unsigned transaction" do
    sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
    recipient_wallet = Wallet.from_json(Wallet.create(true).to_json)

    transaction_id = Transaction.create_id
    transaction = Transaction.new(
      transaction_id,
      "send", # action
      [ a_sender(sender_wallet, 1000.00) ],
      [ a_recipient(recipient_wallet, 10.00) ],
      "0", # message
      "0", # prev_hash
      "0", # sign_r
      "0", # sign_s
    )

    transaction.action.should eq("send")
    senders = transaction.senders
    senders.size.should eq(1)
    senders.first[:address].should eq(sender_wallet.address)
    senders.first[:px].should eq(sender_wallet.public_key_x)
    senders.first[:py].should eq(sender_wallet.public_key_y)
    senders.first[:amount].should eq(1000.00)

    recipients = transaction.recipients
    recipients.size.should eq(1)
    recipients.first[:address].should eq(recipient_wallet.address)
    recipients.first[:amount].should eq(10.00)

    transaction.id.should eq(transaction_id)
    transaction.message.should eq("0")
    transaction.prev_hash.should eq("0")
    transaction.sign_r.should eq("0")
    transaction.sign_s.should eq("0")
  end

  describe "#valid?" do

    context "when not coinbase" do

      it "should be valid" do
        sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
        recipient_wallet = Wallet.from_json(Wallet.create(true).to_json)

        unsigned_transaction = Transaction.new(
          Transaction.create_id,
          "send", # action
          [ a_sender(sender_wallet, 1000.00) ],
          [ a_recipient(recipient_wallet, 10.00) ],
          "0", # message
          "0", # prev_hash
          "0", # sign_r
          "0", # sign_s
        )

        blockchain = Blockchain.new(sender_wallet)
        signature = sign(sender_wallet, unsigned_transaction)
        signed_transaction = unsigned_transaction.signed(signature[:r],signature[:s])

        signed_transaction.sign_r.should eq(signature[:r])
        signed_transaction.sign_s.should eq(signature[:s])

        signed_transaction.valid?(blockchain, 0_i64, false).should be_true
      end

      it "should raise invalid id length error if not 64" do
        sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
        blockchain = Blockchain.new(sender_wallet)

        transaction = Transaction.new(
          "too-short-id",
          "send", # action
          [] of Sender,
          [] of Recipient,
          "0", # message
          "0", # prev_hash
          "0", # sign_r
          "0", # sign_s
        )

        expect_raises(Exception, "Length of transaction id have to be 64: too-short-id") do
          transaction.valid?(blockchain, 0_i64, false)
        end
      end

      it "should raise message exceeds limit error if message bytesize exceeds the limit" do
        sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
        blockchain = Blockchain.new(sender_wallet)

        transaction = Transaction.new(
          Transaction.create_id,
          "send", # action
          [] of Sender,
          [] of Recipient,
          ("exceeds"*100), # message
          "0", # prev_hash
          "0", # sign_r
          "0", # sign_s
        )

        expect_raises(Exception, "Message size exceeds: 700 for 512") do
          transaction.valid?(blockchain, 0_i64, false)
        end
      end

      it "should raise unknown action error if supplied action is not in the list of valid actions" do
        sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
        blockchain = Blockchain.new(sender_wallet)

        transaction = Transaction.new(
          Transaction.create_id,
          "not-valid-action", # action
          [] of Sender,
          [] of Recipient,
          "0", # message
          "0", # prev_hash
          "0", # sign_r
          "0", # sign_s
        )

        expect_raises(Exception, "Unknown action: not-valid-action") do
          transaction.valid?(blockchain, 0_i64, false)
        end
      end

      it "should raise invalid senders address checksum error if supplied sender address is invalid" do
        sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
        blockchain = Blockchain.new(sender_wallet)

        invalid_sender = {
          address: "invalid-wallet-address",
          px: sender_wallet.public_key_x,
          py: sender_wallet.public_key_y,
          amount: 1000.00}

        transaction = Transaction.new(
          Transaction.create_id,
          "send", # action
          [ invalid_sender ],
          [] of Recipient,
          "0", # message
          "0", # prev_hash
          "0", # sign_r
          "0", # sign_s
        )

        expect_raises(Exception, "Invalid checksum for sender's address: invalid-wallet-address") do
          transaction.valid?(blockchain, 0_i64, false)
        end
      end

      it "should raise invalid recipient address checksum error if supplied recipient address is invalid" do
        sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
        blockchain = Blockchain.new(sender_wallet)

        invalid_recipient = {
          address: "invalid-wallet-address",
          amount: 1000.00}

        transaction = Transaction.new(
          Transaction.create_id,
          "send", # action
          [ a_sender(sender_wallet, 1000.00) ],
          [ invalid_recipient ],
          "0", # message
          "0", # prev_hash
          "0", # sign_r
          "0", # sign_s
        )

        expect_raises(Exception, "Invalid checksum for recipient's address: invalid-wallet-address") do
          transaction.valid?(blockchain, 0_i64, false)
        end
      end

      it "should raise invalid number of senders error when the amount of senders is not 1" do
        sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
        blockchain = Blockchain.new(sender_wallet)

        transaction = Transaction.new(
          Transaction.create_id,
          "send", # action
          [] of Sender,
          [] of Recipient,
          "0", # message
          "0", # prev_hash
          "0", # sign_r
          "0", # sign_s
        )

        expect_raises(Exception, "Sender have to be only one currently") do
          transaction.valid?(blockchain, 0_i64, false)
        end
      end

      it "should raise invalid signing error when the signature is invalid" do
        sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
        recipient_wallet = Wallet.from_json(Wallet.create(true).to_json)
        blockchain = Blockchain.new(sender_wallet)

        transaction = Transaction.new(
          Transaction.create_id,
          "send", # action
          [ a_sender(sender_wallet, 1000.00) ],
          [ a_recipient(recipient_wallet, 10.00) ],
          "0", # message
          "0", # prev_hash
          "0", # sign_r
          "0", # sign_s
        )

        expect_raises(Exception, "Invalid signing") do
          transaction.valid?(blockchain, 0_i64, false)
        end
      end

      it "should raise not enough fee error if the sender can't afford the fee" do
        sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
        recipient_wallet = Wallet.from_json(Wallet.create(true).to_json)
        blockchain = Blockchain.new(sender_wallet)

        unsigned_transaction = Transaction.new(
          Transaction.create_id,
          "send", # action
          [ a_sender(sender_wallet, 0.0) ],
          [ a_recipient(recipient_wallet, 10.00) ],
          "0", # message
          "0", # prev_hash
          "0", # sign_r
          "0", # sign_s
        )

        signature = sign(sender_wallet, unsigned_transaction)
        signed_transaction = unsigned_transaction.signed(signature[:r],signature[:s])

        expect_raises(Exception, "Not enough fee, should be  -10.0 >= 0.1") do
          signed_transaction.valid?(blockchain, 0_i64, false)
        end
      end

      it "should raise not enough coins error if the sender can't afford to pay the amount" do
        sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
        recipient_wallet = Wallet.from_json(Wallet.create(true).to_json)
        blockchain = Blockchain.new(sender_wallet)

        unsigned_transaction = Transaction.new(
          Transaction.create_id,
          "send", # action
          [ a_sender(sender_wallet, 10000.01) ],
          [ a_recipient(recipient_wallet, 10.00) ],
          "0", # message
          "0", # prev_hash
          "0", # sign_r
          "0", # sign_s
        )

        signature = sign(sender_wallet, unsigned_transaction)
        signed_transaction = unsigned_transaction.signed(signature[:r],signature[:s])

        expect_raises(Exception, "Sender has not enough coins: #{sender_wallet.address} (10000.0)") do
          signed_transaction.valid?(blockchain, 0_i64, false)
        end
      end
    end

    context "when coinbase" do

      # Every block must have a coinbase transaction, other transactions are optional.
      # The coinbase transaction must be the first transaction of the block (it follows that there can only be one per block).
      # The coinbase's output is used to send the block reward, i.e. block subsidy plus transaction fees, to the miner's address.

      it "should be valid" do

        sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
        recipient_wallet = Wallet.from_json(Wallet.create(true).to_json)

        unsigned_transaction = Transaction.new(
          Transaction.create_id,
          "head", # action
          [] of Sender,
          [ a_recipient(recipient_wallet, 10000.00) ],
          "0", # message
          "0", # prev_hash
          "0", # sign_r
          "0", # sign_s
        )

        blockchain = Blockchain.new(sender_wallet)
        unsigned_transaction.valid?(blockchain, 0_i64, true).should be_true
      end

      it "should raise message should be '0' error if supplied coinbase message is not '0'" do
        sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
        blockchain = Blockchain.new(sender_wallet)

        transaction = Transaction.new(
          Transaction.create_id,
          "head", # action
          [] of Sender,
          [] of Recipient,
          "1", # message
          "0", # prev_hash
          "0", # sign_r
          "0", # sign_s
        )

        expect_raises(Exception, "message has to be '0' for coinbase transaction") do
          transaction.valid?(blockchain, 0_i64, true)
        end
      end

      it "should raise action should be 'head' error if supplied coinbase action is not 'head'" do
        sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
        blockchain = Blockchain.new(sender_wallet)

        transaction = Transaction.new(
          Transaction.create_id,
          "send", # action
          [] of Sender,
          [] of Recipient,
          "0", # message
          "0", # prev_hash
          "0", # sign_r
          "0", # sign_s
        )

        expect_raises(Exception, "actions has to be 'head' for coinbase transaction") do
          transaction.valid?(blockchain, 0_i64, true)
        end
      end

      it "should raise error if supplied coinbase sender is not empty" do
        sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
        blockchain = Blockchain.new(sender_wallet)

        transaction = Transaction.new(
          Transaction.create_id,
          "head", # action
          [ a_sender(sender_wallet, 10000.01) ],
          [] of Recipient,
          "0", # message
          "0", # prev_hash
          "0", # sign_r
          "0", # sign_s
        )

        expect_raises(Exception, "there should be no Sender for a coinbase transaction") do
          transaction.valid?(blockchain, 0_i64, true)
        end
      end

      it "should raise error if supplied coinbase prev_hash is not '0'" do
        sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
        blockchain = Blockchain.new(sender_wallet)

        transaction = Transaction.new(
          Transaction.create_id,
          "head", # action
          [] of Sender,
          [] of Recipient,
          "0", # message
          "1", # prev_hash
          "0", # sign_r
          "0", # sign_s
        )

        expect_raises(Exception, "prev_hash of coinbase transaction has to be '0'") do
          transaction.valid?(blockchain, 0_i64, true)
        end
      end

      it "should raise error if supplied coinbase sign_r is not '0'" do
        sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
        blockchain = Blockchain.new(sender_wallet)

        transaction = Transaction.new(
          Transaction.create_id,
          "head", # action
          [] of Sender,
          [] of Recipient,
          "0", # message
          "0", # prev_hash
          "1", # sign_r
          "0", # sign_s
        )

        expect_raises(Exception, "sign_r of coinbase transaction has to be '0'") do
          transaction.valid?(blockchain, 0_i64, true)
        end
      end

      it "should raise error if supplied coinbase sign_s is not '0'" do
        sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
        blockchain = Blockchain.new(sender_wallet)

        transaction = Transaction.new(
          Transaction.create_id,
          "head", # action
          [] of Sender,
          [] of Recipient,
          "0", # message
          "0", # prev_hash
          "0", # sign_r
          "1", # sign_s
        )

        expect_raises(Exception, "sign_s of coinbase transaction has to be '0'") do
          transaction.valid?(blockchain, 0_i64, true)
        end
      end

      it "should raise error when served amount for coinbase transaction does not equal the blockchain amount" do
        sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
        recipient_wallet = Wallet.from_json(Wallet.create(true).to_json)
        blockchain = Blockchain.new(sender_wallet)

        transaction = Transaction.new(
          Transaction.create_id,
          "head", # action
          [] of Sender,
          [ a_recipient(recipient_wallet, 10.00) ],
          "0", # message
          "0", # prev_hash
          "0", # sign_r
          "0", # sign_s
        )

        expect_raises(Exception, "Invalid served amount for coinbase transaction: 10.0") do
          transaction.valid?(blockchain, 0_i64, true)
        end
      end
    end
  end

  it "should add the signatures to the transaction using #signed" do
    sender_wallet = Wallet.from_json(Wallet.create(true).to_json)

    unsigned_transaction = Transaction.new(
      Transaction.create_id,
      "send", # action
      [] of Sender,
      [] of Recipient,
      "0", # message
      "0", # prev_hash
      "0", # sign_r
      "0", # sign_s
    )

    blockchain = Blockchain.new(sender_wallet)
    signature = sign(sender_wallet, unsigned_transaction)
    signed_transaction = unsigned_transaction.signed(signature[:r],signature[:s])

    signed_transaction.sign_r.should eq(signature[:r])
    signed_transaction.sign_s.should eq(signature[:s])
  end

  it "should transform a signed transaction to an unsigned one using #as_unsigned" do
    sender_wallet = Wallet.from_json(Wallet.create(true).to_json)

    unsigned_transaction = Transaction.new(
      Transaction.create_id,
      "send", # action
      [] of Sender,
      [] of Recipient,
      "0", # message
      "0", # prev_hash
      "0", # sign_r
      "0", # sign_s
    )

    blockchain = Blockchain.new(sender_wallet)
    signature = sign(sender_wallet, unsigned_transaction)
    signed_transaction = unsigned_transaction.signed(signature[:r],signature[:s])

    signed_transaction.sign_r.should eq(signature[:r])
    signed_transaction.sign_s.should eq(signature[:s])

    unsigned = signed_transaction.as_unsigned
    unsigned.sign_r.should eq("0")
    unsigned.sign_s.should eq("0")
  end

  it "should get the sender amount with #sender_total_amount" do
    sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
    recipient_wallet = Wallet.from_json(Wallet.create(true).to_json)
    blockchain = Blockchain.new(sender_wallet)

    transaction = Transaction.new(
      Transaction.create_id,
      "send", # action
      [ a_sender(sender_wallet, 10.00) ],
      [ a_recipient(recipient_wallet, 10.00) ],
      "0", # message
      "0", # prev_hash
      "0", # sign_r
      "0", # sign_s
    )

    transaction.sender_total_amount.should eq(10.0)
  end

  it "should get the recipient amount with #recipient_total_amount" do
    sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
    recipient_wallet = Wallet.from_json(Wallet.create(true).to_json)
    blockchain = Blockchain.new(sender_wallet)

    transaction = Transaction.new(
      Transaction.create_id,
      "send", # action
      [ a_sender(sender_wallet, 10.00) ],
      [ a_recipient(recipient_wallet, 10.00) ],
      "0", # message
      "0", # prev_hash
      "0", # sign_r
      "0", # sign_s
    )

    transaction.recipient_total_amount.should eq(10.0)
  end

  it "should get the sender fee amount with #calculate_fee" do
    sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
    recipient_wallet = Wallet.from_json(Wallet.create(true).to_json)
    blockchain = Blockchain.new(sender_wallet)

    transaction = Transaction.new(
      Transaction.create_id,
      "send", # action
      [ a_sender(sender_wallet, 10.01) ],
      [ a_recipient(recipient_wallet, 10.00) ],
      "0", # message
      "0", # prev_hash
      "0", # sign_r
      "0", # sign_s
    )

    transaction.calculate_fee.should eq(0.01)
  end

  it "should calculate unspent transaction outputs with #calculate_utxo" do
    sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
    recipient_wallet = Wallet.from_json(Wallet.create(true).to_json)
    blockchain = Blockchain.new(sender_wallet)

    transaction = Transaction.new(
      Transaction.create_id,
      "send", # action
      [ a_sender(sender_wallet, 10.01) ],
      [ a_recipient(recipient_wallet, 10.00) ],
      "0", # message
      "0", # prev_hash
      "0", # sign_r
      "0", # sign_s
    )

    transaction.calculate_utxo.should eq({sender_wallet.address => -10.01, recipient_wallet.address => 10.0})
  end
end
