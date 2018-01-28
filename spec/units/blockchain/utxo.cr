require "./../../spec_helper"

include Sushi::Core
include Units::Utils

describe UTXO do

  describe "#get" do

    it "should return 0 when the number of blocks is less than confirmations" do
      chain = [genesis_block, block_1]
      utxo = UTXO.new
      utxo.record(chain)

      address = block_1.transactions.first.recipients.first[:address]
      utxo.get(address).should eq(0)
    end

    it "should return address amount when the number of blocks is greater than confirmations" do
      chain = [genesis_block, block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
      utxo = UTXO.new
      utxo.record(chain)

      address = block_1.transactions.first.recipients.first[:address]
      expected_amount = chain.reject{|blk| blk.prev_hash == "genesis"}.flat_map{|blk| blk.transactions.first.recipients.select{|r| r[:address] == address} }.map{|x| x[:amount]}.sum

      utxo.get(address).should eq(expected_amount)
    end

    context "when address does not exist" do

      it "should return 0 when the number of blocks is less than confirmations and the address is not found" do
        chain = [genesis_block, block_1]
        utxo = UTXO.new
        utxo.record(chain)

        utxo.get("address-does-not-exist").should eq(0)
      end

      it "should return address amount when the number of blocks is greater than confirmations and the address is not found" do
        chain = [genesis_block, block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
        utxo = UTXO.new
        utxo.record(chain)

        utxo.get("address-does-not-exist").should eq(0)
      end
    end
  end

  describe "#get_unconfirmed" do

    it "should get unconfirmed transactions amount for the supplied address in the supplied transactions" do
      chain = [genesis_block, block_1]
      utxo = UTXO.new
      utxo.record(chain)

      transactions = chain.reject{|blk| blk.prev_hash == "genesis"}.flat_map{|blk| blk.transactions }
      address = block_1.transactions.first.recipients.first[:address]
      expected_amount = transactions.flat_map{|txn| txn.recipients.select{|r| r[:address] == address} }.map{|x| x[:amount]}.sum * 2
      utxo.get_unconfirmed(address, transactions).should eq(expected_amount)
    end

    it "should get unconfirmed transactions amount for the supplied address when no transactions are supplied" do
      chain = [genesis_block, block_1]
      utxo = UTXO.new
      utxo.record(chain)

      transactions = [] of Transaction
      address = block_1.transactions.first.recipients.first[:address]
      expected_amount = chain.reject{|blk| blk.prev_hash == "genesis"}.flat_map{|blk| blk.transactions.first.recipients.select{|r| r[:address] == address} }.map{|x| x[:amount]}.sum
      utxo.get_unconfirmed(address, transactions).should eq(expected_amount)
    end

    context "when chain is empty" do

      it "should get unconfirmed transactions amount for the supplied address when no transactions are supplied and the chain is empty" do
        chain = [] of Block
        utxo = UTXO.new
        utxo.record(chain)

        transactions = [] of Transaction
        address = block_1.transactions.first.recipients.first[:address]
        utxo.get_unconfirmed(address, transactions).should eq(0)
      end

      it "should get unconfirmed transactions when no transactions are supplied and the chain is empty and the address is unknown" do
        chain = [] of Block
        utxo = UTXO.new
        utxo.record(chain)

        transactions = [] of Transaction
        utxo.get_unconfirmed("address-does-not-exist", transactions).should eq(0)
      end
    end
  end

  describe "#get_unconfirmed_recorded" do

    it "should return 0 when there are no transactions" do
      chain = [] of Block
      utxo = UTXO.new
      utxo.record(chain)

      address = block_1.transactions.first.recipients.first[:address]
      utxo.get_unconfirmed_recorded(address).should eq(0)
    end

    it "should return the correct amount when transactions" do
      chain = [genesis_block, block_1]
      utxo = UTXO.new
      utxo.record(chain)

      address = block_1.transactions.first.recipients.first[:address]
      expected_amount = chain.reject{|blk| blk.prev_hash == "genesis"}.flat_map{|blk| blk.transactions.first.recipients.select{|r| r[:address] == address} }.map{|x| x[:amount]}.sum
      utxo.get_unconfirmed_recorded(address).should eq(expected_amount)
    end

    it "should return 0 when an non existing address is supplied" do
      chain = [genesis_block, block_1]
      utxo = UTXO.new
      utxo.record(chain)

      utxo.get_unconfirmed_recorded("address-does-not-exist").should eq(0)
    end
  end

  describe "#index" do

    it "should return a block index for supplied transaction id" do
      chain = [genesis_block, block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
      utxo = UTXO.new
      utxo.record(chain)

      transaction_id = block_1.transactions.first.id
      utxo.index(transaction_id).should eq(1_i64)
    end

    it "should return nil when supplied transaction id is not found" do
      chain = [genesis_block, block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
      utxo = UTXO.new
      utxo.record(chain)

      utxo.index("transaction-id-does-not-exist").should be_nil
    end
  end

  it "should clear the internal transaction lists with #clear" do
    chain = [genesis_block, block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
    utxo = UTXO.new
    utxo.record(chain)

    utxo.@transaction_indices.size.should eq(10)
    utxo.@utxo_internal.size.should eq(11)

    utxo.clear

    utxo.@transaction_indices.size.should eq(0)
    utxo.@utxo_internal.size.should eq(0)
  end

  STDERR.puts "< UTXO"
end
