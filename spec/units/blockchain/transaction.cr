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
      [a_sender(sender_wallet, 1000_i64)],
      [a_recipient(recipient_wallet, 10_i64)],
      "0", # message
      "0", # prev_hash
      "0", # sign_r
      "0", # sign_s
    )

    transaction.action.should eq("send")
    senders = transaction.senders
    senders.size.should eq(1)
    senders.first[:address].should eq(sender_wallet.address)
    senders.first[:public_key].should eq(sender_wallet.public_key)
    senders.first[:amount].should eq(1000_i64)

    recipients = transaction.recipients
    recipients.size.should eq(1)
    recipients.first[:address].should eq(recipient_wallet.address)
    recipients.first[:amount].should eq(10_i64)

    transaction.id.should eq(transaction_id)
    transaction.message.should eq("0")
    transaction.prev_hash.should eq("0")
    transaction.sign_r.should eq("0")
    transaction.sign_s.should eq("0")
  end

  describe "#valid?" do
    context "when not coinbase" do
      it "should be valid" do
        with_factory do |block_factory, transaction_factory|
          signed_transaction1 = transaction_factory.make_send(100_i64)
          signed_transaction2 = transaction_factory.make_send(200_i64)
          signed_transaction2 = transaction_factory.align_transaction(signed_transaction2, signed_transaction1.to_hash)

          blockchain = Blockchain.new(transaction_factory.sender_wallet)
          blockchain.replace_chain(block_factory.addBlocks(1).sub_chain)
          signed_transaction2.valid?(blockchain, 0_i64, false, [signed_transaction1]).should be_true
        end
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

        expect_raises(Exception, "length of transaction id have to be 64: too-short-id") do
          transaction.valid?(blockchain, 0_i64, false, [] of Transaction)
        end
      end

      it "should raise error: transaction already included in indices" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_send(100_i64)
          transaction2 = transaction_factory.make_send(200_i64)
          chain = block_factory.addBlock.addBlock([transaction1, transaction2]).sub_chain
          blockchain = Blockchain.new(transaction_factory.sender_wallet)
          blockchain.replace_chain(chain)

          transaction1 = transaction_factory.align_transaction(transaction1, blockchain.chain.last.transactions.last.to_hash)
          expect_raises(Exception, "the transaction #{transaction1.id} is already included in 2") do
            transaction1.valid?(blockchain, 0_i64, false, blockchain.chain.last.transactions)
          end
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
          "0",             # prev_hash
          "0",             # sign_r
          "0",             # sign_s
        )

        expect_raises(Exception, "message size exceeds: 700 for 512") do
          transaction.valid?(blockchain, 0_i64, false, [] of Transaction)
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

        expect_raises(Exception, "unknown action: not-valid-action") do
          transaction.valid?(blockchain, 0_i64, false, [] of Transaction)
        end
      end

      it "should raise invalid senders address checksum error if supplied sender address is invalid" do
        sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
        blockchain = Blockchain.new(sender_wallet)

        invalid_sender = {
          address:    Base64.strict_encode("T0invalid-wallet-address"),
          public_key: sender_wallet.public_key,
          amount:     1000_i64,
          fee:        1_i64,
        }

        transaction = Transaction.new(
          Transaction.create_id,
          "send", # action
          [invalid_sender],
          [] of Recipient,
          "0", # message
          "0", # prev_hash
          "0", # sign_r
          "0", # sign_s
        )

        expect_raises(Exception, "invalid sender address checksum for: VDBpbnZhbGlkLXdhbGxldC1hZGRyZXNz") do
          transaction.valid?(blockchain, 0_i64, false, [] of Transaction)
        end
      end

      it "should raise invalid recipient address checksum error if supplied recipient address is invalid" do
        sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
        blockchain = Blockchain.new(sender_wallet)

        invalid_recipient = {
          address: Base64.strict_encode("T0invalid-wallet-address"),
          amount:  1000_i64,
        }

        transaction = Transaction.new(
          Transaction.create_id,
          "send", # action
          [a_sender(sender_wallet, 1000_i64)],
          [invalid_recipient],
          "0", # message
          "0", # prev_hash
          "0", # sign_r
          "0", # sign_s
        )

        expect_raises(Exception, "invalid recipient address checksum for: VDBpbnZhbGlkLXdhbGxldC1hZGRyZXNz") do
          transaction.valid?(blockchain, 0_i64, false, [] of Transaction)
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

        expect_raises(Exception, "sender have to be only one currently") do
          transaction.valid?(blockchain, 0_i64, false, [] of Transaction)
        end
      end

      it "should raise error when there are no transactions" do
        sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
        blockchain = Blockchain.new(sender_wallet)

        transaction = Transaction.new(
          Transaction.create_id,
          "send", # action
          [a_sender(sender_wallet, 1000_i64)],
          [] of Recipient,
          "0", # message
          "0", # prev_hash
          "0", # sign_r
          "0", # sign_s
        )

        expect_raises(Exception, "There must be some transactions") do
          transaction.valid?(blockchain, 0_i64, false, [] of Transaction)
        end
      end

      it "should raise invalid signing error when the signature is invalid" do
        with_factory do |block_factory, transaction_factory|
          signed_transaction1 = transaction_factory.make_send(100_i64)
          signed_transaction2 = transaction_factory.make_send_with_prev_hash(200_i64, signed_transaction1.to_hash)

          blockchain = Blockchain.new(transaction_factory.sender_wallet)

          expect_raises(Exception, "invalid signing") do
            signed_transaction2.valid?(blockchain, 0_i64, false, [signed_transaction1])
          end
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
          [a_recipient(recipient_wallet, 10000_i64)],
          "0", # message
          "0", # prev_hash
          "0", # sign_r
          "0", # sign_s
        )

        blockchain = Blockchain.new(sender_wallet)
        unsigned_transaction.valid?(blockchain, 0_i64, true, [] of Transaction)
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
          transaction.valid?(blockchain, 0_i64, true, [] of Transaction)
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
          transaction.valid?(blockchain, 0_i64, true, [] of Transaction)
        end
      end

      it "should raise error if supplied coinbase sender is not empty" do
        sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
        blockchain = Blockchain.new(sender_wallet)

        transaction = Transaction.new(
          Transaction.create_id,
          "head", # action
          [a_sender(sender_wallet, 10001_i64)],
          [] of Recipient,
          "0", # message
          "0", # prev_hash
          "0", # sign_r
          "0", # sign_s
        )

        expect_raises(Exception, "there should be no Sender for a coinbase transaction") do
          transaction.valid?(blockchain, 0_i64, true, [] of Transaction)
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
          transaction.valid?(blockchain, 0_i64, true, [] of Transaction)
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
          transaction.valid?(blockchain, 0_i64, true, [] of Transaction)
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
          transaction.valid?(blockchain, 0_i64, true, [] of Transaction)
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
          [a_recipient(recipient_wallet, 10_i64)],
          "0", # message
          "0", # prev_hash
          "0", # sign_r
          "0", # sign_s
        )

        expect_raises(Exception, "invalid served amount for coinbase transaction: 10") do
          transaction.valid?(blockchain, 0_i64, true, [] of Transaction)
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
    signed_transaction = unsigned_transaction.signed(signature[:r], signature[:s])

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
    signed_transaction = unsigned_transaction.signed(signature[:r], signature[:s])

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
      [a_sender(sender_wallet, 10_i64)],
      [a_recipient(recipient_wallet, 10_i64)],
      "0", # message
      "0", # prev_hash
      "0", # sign_r
      "0", # sign_s
    )

    transaction.sender_total_amount.should eq(10_i64)
  end

  it "should get the recipient amount with #recipient_total_amount" do
    sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
    recipient_wallet = Wallet.from_json(Wallet.create(true).to_json)
    blockchain = Blockchain.new(sender_wallet)

    transaction = Transaction.new(
      Transaction.create_id,
      "send", # action
      [a_sender(sender_wallet, 10_i64)],
      [a_recipient(recipient_wallet, 10_i64)],
      "0", # message
      "0", # prev_hash
      "0", # sign_r
      "0", # sign_s
    )

    transaction.recipient_total_amount.should eq(10_i64)
  end

  it "should get the sender fee amount with #calculate_fee" do
    sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
    recipient_wallet = Wallet.from_json(Wallet.create(true).to_json)
    blockchain = Blockchain.new(sender_wallet)

    transaction = Transaction.new(
      Transaction.create_id,
      "send", # action
      [a_sender(sender_wallet, 11_i64)],
      [a_recipient(recipient_wallet, 10_i64)],
      "0", # message
      "0", # prev_hash
      "0", # sign_r
      "0", # sign_s
    )

    transaction.calculate_fee.should eq(1_i64)
  end

  # it "should calculate unspent transaction outputs with #calculate_utxo" do
  #   sender_wallet = Wallet.from_json(Wallet.create(true).to_json)
  #   recipient_wallet = Wallet.from_json(Wallet.create(true).to_json)
  #   blockchain = Blockchain.new(sender_wallet)
  #
  #   transaction = Transaction.new(
  #     Transaction.create_id,
  #     "send", # action
  #     [a_sender(sender_wallet, 11_i64)],
  #     [a_recipient(recipient_wallet, 10_i64)],
  #     "0", # message
  #     "0", # prev_hash
  #     "0", # sign_r
  #     "0", # sign_s
  #   )
  #
  #   transaction.calculate_utxo.should eq({sender_wallet.address => -11_i64, recipient_wallet.address => 10_i64})
  # end

  STDERR.puts "< Transaction"
end
