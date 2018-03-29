require "./../../../spec_helper"
require "./../../utils"

include Sushi::Core
include Sushi::Core::Models
include Units::Utils
include Sushi::Core::DApps::BuildIn

describe UTXO do
  describe "#get" do
    it "should return 0 when the number of blocks is less than confirmations" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlock.chain
        utxo = UTXO.new(Blockchain.new(transaction_factory.sender_wallet))
        utxo.record(chain)

        address = block_1.transactions.first.recipients.first[:address]
        utxo.get(address, TOKEN_DEFAULT).should eq(0)
      end
    end

    it "should return address amount when the number of blocks is greater than confirmations" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlocks(10).chain
        utxo = UTXO.new(Blockchain.new(transaction_factory.sender_wallet))
        utxo.record(chain)

        address = chain[1].transactions.first.recipients.first[:address]
        expected_amount = block_1.transactions[0].recipients[0]["amount"]

        utxo.get(address, TOKEN_DEFAULT).should eq(expected_amount)
      end
    end

    context "when address does not exist" do
      it "should return 0 when the number of blocks is less than confirmations and the address is not found" do
        with_factory do |block_factory, transaction_factory|
          chain = block_factory.addBlock.chain
          utxo = UTXO.new(Blockchain.new(transaction_factory.sender_wallet))
          utxo.record(chain)

          utxo.get("address-does-not-exist", TOKEN_DEFAULT).should eq(0)
        end
      end

      it "should return address amount when the number of blocks is greater than confirmations and the address is not found" do
        with_factory do |block_factory, transaction_factory|
          chain = block_factory.addBlocks(10).chain
          utxo = UTXO.new(Blockchain.new(transaction_factory.sender_wallet))
          utxo.record(chain)

          utxo.get("address-does-not-exist", TOKEN_DEFAULT).should eq(0)
        end
      end
    end

    context "when token does not exist" do
      it "should return 0 when the number of blocks is less than confirmations and the token is not found" do
        with_factory do |block_factory, transaction_factory|
          chain = block_factory.addBlock.chain
          utxo = UTXO.new(Blockchain.new(transaction_factory.sender_wallet))
          utxo.record(chain)
          address = chain[1].transactions.first.recipients.first[:address]

          utxo.get(address, "UNKNOWN").should eq(0)
        end
      end

      it "should return address amount when the number of blocks is greater than confirmations and the token is not found" do
        with_factory do |block_factory, transaction_factory|
          chain = block_factory.addBlocks(10).chain
          utxo = UTXO.new(Blockchain.new(transaction_factory.sender_wallet))
          utxo.record(chain)
          address = chain[1].transactions.first.recipients.first[:address]

          utxo.get(address, "UNKNOWN").should eq(0)
        end
      end
    end
  end

  describe "#get_unconfirmed" do
    it "should get unconfirmed transactions amount for the supplied address in the supplied transactions" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlock.chain
        utxo = UTXO.new(Blockchain.new(transaction_factory.sender_wallet))
        utxo.record(chain)

        transactions = chain.reject { |blk| blk.prev_hash == "genesis" }.flat_map { |blk| blk.transactions }
        address = chain[1].transactions.first.recipients.first[:address]
        expected_amount = transactions.flat_map { |txn| txn.recipients.select { |r| r[:address] == address } }.map { |x| x[:amount] }.sum * 2
        utxo.get_unconfirmed(address, transactions, TOKEN_DEFAULT).should eq(expected_amount)
      end
    end

    it "should get unconfirmed transactions amount for the supplied address when no transactions are supplied" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlock.chain
        utxo = UTXO.new(Blockchain.new(transaction_factory.sender_wallet))
        utxo.record(chain)

        transactions = [] of Transaction
        address = chain[1].transactions.first.recipients.first[:address]
        expected_amount = chain.reject { |blk| blk.prev_hash == "genesis" }.flat_map { |blk| blk.transactions.first.recipients.select { |r| r[:address] == address } }.map { |x| x[:amount] }.sum
        utxo.get_unconfirmed(address, transactions, TOKEN_DEFAULT).should eq(expected_amount)
      end
    end

    context "when chain is empty" do
      it "should get unconfirmed transactions amount for the supplied address when no transactions are supplied and the chain is empty" do
        with_factory do |block_factory, transaction_factory|
          chain = [] of Block
          utxo = UTXO.new(Blockchain.new(transaction_factory.sender_wallet))
          utxo.record(chain)

          transactions = [] of Transaction
          address = "any-address"
          utxo.get_unconfirmed(address, transactions, TOKEN_DEFAULT).should eq(0)
        end
      end

      it "should get unconfirmed transactions when no transactions are supplied and the chain is empty and the address is unknown" do
        with_factory do |block_factory, transaction_factory|
          chain = [] of Block
          utxo = UTXO.new(Blockchain.new(transaction_factory.sender_wallet))
          utxo.record(chain)

          transactions = [] of Transaction
          utxo.get_unconfirmed("address-does-not-exist", transactions, TOKEN_DEFAULT).should eq(0)
        end
      end
    end
  end

  describe "#transaction_actions" do
    it "should return actions" do
      with_factory do |block_factory, transaction_factory|
        utxo = UTXO.new(Blockchain.new(transaction_factory.sender_wallet))
        utxo.transaction_actions.should eq(["send"])
      end
    end
  end

  describe "#transaction_related?" do
    it "should always return true" do
      with_factory do |block_factory, transaction_factory|
        utxo = UTXO.new(Blockchain.new(transaction_factory.sender_wallet))
        utxo.transaction_related?("whatever").should be_true
      end
    end
  end

  pending "#valid_transaction?" do
    it "return true if valid transaction" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlock.chain
        utxo = UTXO.new(Blockchain.new(transaction_factory.sender_wallet))
        # utxo.record(chain)
        # utxo.valid_transaction?(txn1, txns).should be_true
      end
    end
  end
  # it "should clear the internal transaction lists with #clear" do
  #   chain = [genesis_block, block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
  #   utxo = UTXO.new
  #   utxo.record(chain)
  #
  #   utxo.@utxo_internal.size.should eq(11)
  #   utxo.clear
  #   utxo.@utxo_internal.size.should eq(0)
  # end

  STDERR.puts "< UTXO"
end
