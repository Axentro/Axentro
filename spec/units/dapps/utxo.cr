# Copyright © 2017-2020 The Axentro Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the Axentro Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

require "./../../spec_helper"

include Axentro::Core
include Units::Utils
include Axentro::Core::DApps::BuildIn
include Axentro::Core::Controllers

describe UTXO do
  describe "#get_for_batch" do
    it "should get the amount for the supplied token and address" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_blocks(10).chain
        utxo = UTXO.new(block_factory.blockchain)
        utxo.record(chain)
        address = chain[1].transactions.first.recipients.first[:address]
        historic_per_address = {address => [TokenQuantity.new(TOKEN_DEFAULT, 11999965560_i64)]}

        utxo.get_for_batch(address, TOKEN_DEFAULT, historic_per_address).should eq(11999965560_i64)
      end
    end
  end

  describe "#get_for_batch" do
    context "when address does not exist" do
      it "should return 0 when the number of blocks is less than confirmations and the address is not found" do
        with_factory do |block_factory, _|
          chain = block_factory.add_slow_block.chain
          utxo = UTXO.new(block_factory.blockchain)
          utxo.record(chain)
          historic_per_address = {} of String => Array(TokenQuantity)

          utxo.get_for_batch("address-does-not-exist", TOKEN_DEFAULT, historic_per_address).should eq(0)
        end
      end

      it "should return address amount when the number of blocks is greater than confirmations and the address is not found" do
        with_factory do |block_factory, _|
          chain = block_factory.add_slow_blocks(10).chain
          utxo = UTXO.new(block_factory.blockchain)
          utxo.record(chain)
          historic_per_address = {} of String => Array(TokenQuantity)

          utxo.get_for_batch("address-does-not-exist", TOKEN_DEFAULT, historic_per_address).should eq(0)
        end
      end
    end

    context "when token does not exist" do
      it "should return 0 when the number of blocks is less than confirmations and the token is not found" do
        with_factory do |block_factory, _|
          chain = block_factory.add_slow_block.chain
          utxo = UTXO.new(block_factory.blockchain)
          utxo.record(chain)
          address = chain[1].transactions.first.recipients.first[:address]
          historic_per_address = {address => [TokenQuantity.new(TOKEN_DEFAULT, 11999965560_i64)]}

          utxo.get_for_batch(address, "UNKNOWN", historic_per_address).should eq(0)
        end
      end

      it "should return address amount when the number of blocks is greater than confirmations and the token is not found" do
        with_factory do |block_factory, _|
          chain = block_factory.add_slow_blocks(10).chain
          utxo = UTXO.new(block_factory.blockchain)
          utxo.record(chain)
          address = chain[1].transactions.first.recipients.first[:address]
          historic_per_address = {address => [TokenQuantity.new(TOKEN_DEFAULT, 11999965560_i64)]}

          utxo.get_for_batch(address, "UNKNOWN", historic_per_address).should eq(0)
        end
      end
    end
  end

  describe "#get_pending_batch" do
    it "should get pending transactions amount for the supplied address in the supplied transactions" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_block.chain
        utxo = UTXO.new(block_factory.blockchain)
        utxo.record(chain)

        transactions = chain.reject { |blk| blk.prev_hash == "genesis" }.flat_map { |blk| blk.transactions }
        address = chain[1].transactions.first.recipients.first[:address]
        expected_amount = transactions.flat_map { |txn| txn.recipients.select { |r| r[:address] == address } }.map { |x| x[:amount] }.sum * 2
        historic_per_address = {address => [TokenQuantity.new(TOKEN_DEFAULT, expected_amount - 1199999373_i64)]}

        utxo.get_pending_batch(address, transactions, TOKEN_DEFAULT, historic_per_address).should eq(expected_amount)
      end
    end

    it "should get pending transactions amount for the supplied address when no transactions are supplied" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_block.chain
        utxo = UTXO.new(block_factory.blockchain)
        utxo.record(chain)

        transactions = [] of Transaction
        address = chain[1].transactions.first.recipients.first[:address]
        expected_amount = chain.reject { |blk| blk.prev_hash == "genesis" }.flat_map { |blk| blk.transactions.first.recipients.select { |r| r[:address] == address } }.map { |x| x[:amount] }.sum
        historic_per_address = {address => [TokenQuantity.new(TOKEN_DEFAULT, expected_amount)]}

        utxo.get_pending_batch(address, transactions, TOKEN_DEFAULT, historic_per_address).should eq(expected_amount)
      end
    end

    context "when chain is empty" do
      it "should get pending transactions amount for the supplied address when no transactions are supplied and the chain is empty" do
        with_factory do |block_factory, _|
          chain = [] of SlowBlock
          utxo = UTXO.new(block_factory.blockchain)
          utxo.record(chain)
          historic_per_address = {} of String => Array(TokenQuantity)

          transactions = [] of Transaction
          address = "any-address"

          utxo.get_pending_batch(address, transactions, TOKEN_DEFAULT, historic_per_address).should eq(0)
        end
      end

      it "should get pending transactions when no transactions are supplied and the chain is empty and the address is unknown" do
        with_factory do |block_factory, _|
          chain = [] of SlowBlock
          utxo = UTXO.new(block_factory.blockchain)
          utxo.record(chain)
          historic_per_address = {} of String => Array(TokenQuantity)

          transactions = [] of Transaction
          utxo.get_pending_batch("address-does-not-exist", transactions, TOKEN_DEFAULT, historic_per_address).should eq(0)
        end
      end
    end
  end

  describe "#transaction_actions" do
    it "should return actions" do
      with_factory do |block_factory, _|
        utxo = UTXO.new(block_factory.blockchain)
        utxo.transaction_actions.should eq(["send"])
      end
    end
  end

  describe "#transaction_related?" do
    it "should only return true for all internal actions" do
      with_factory do |block_factory, _|
        utxo = UTXO.new(block_factory.blockchain)
        utxo.transaction_related?("whatever").should be_false
        Axentro::Core::Data::Transactions::INTERNAL_ACTIONS.each do |action|
          utxo.transaction_related?(action).should be_true
        end
      end
    end
  end

  describe "#valid_transactions?" do
    it "should return true if valid transaction" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_send(100_i64)
        transaction2 = transaction_factory.make_send(200_i64)
        chain = block_factory.add_slow_blocks(10).chain
        utxo = UTXO.new(block_factory.blockchain)
        utxo.record(chain)
        transactions = [transaction1, transaction2]
        result = utxo.valid_transactions?(transactions)

        result.passed.size.should eq(2)
        result.failed.size.should eq(0)
        transactions.map(&.id).each do |tid|
          result.passed.map(&.id).includes?(tid).should eq(true)
        end
      end
    end

    it "should raise an error if has a recipient" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_send(100_i64)
        transaction2 = transaction_factory.make_send(200_i64)
        chain = block_factory.add_slow_block.chain
        utxo = UTXO.new(block_factory.blockchain)
        transaction2.recipients = [a_recipient(transaction_factory.recipient_wallet, 10_i64), a_recipient(transaction_factory.recipient_wallet, 10_i64)]
        utxo.record(chain)

        result = utxo.valid_transactions?([transaction1, transaction2])
        result.failed.size.should eq(1)
        result.passed.size.should eq(1)
        result.failed.first.reason.should eq("there must be 1 or less recipients")
      end
    end

    it "should raise an error if has no senders" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_send(100_i64)
        transaction2 = transaction_factory.make_send(200_i64)
        chain = block_factory.add_slow_block.chain
        utxo = UTXO.new(block_factory.blockchain)
        transaction2.senders = [] of Transaction::Sender
        utxo.record(chain)

        result = utxo.valid_transactions?([transaction1, transaction2])
        result.failed.size.should eq(1)
        result.passed.size.should eq(1)
        result.failed.first.reason.should eq("there must be 1 sender")
      end
    end

    it "should raise an error if sender does not have enough tokens to afford the transaction" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_send(100000000_i64)
        transaction2 = transaction_factory.make_send(2000000000_i64)
        chain = block_factory.add_slow_blocks(1).chain
        utxo = UTXO.new(block_factory.blockchain)
        utxo.record(chain)

        result = utxo.valid_transactions?([transaction1, transaction2])
        result.failed.size.should eq(1)
        result.passed.size.should eq(1)
        result.failed.first.reason.should eq("Unable to send 20 AXNT to recipient because you do not have enough AXNT. You currently have: 10.99989373 AXNT and you are receiving: 0 AXNT from senders,  giving a total of: 10.99989373 AXNT")
      end
    end

    it "should raise an error if sender does not have enough custom tokens to afford the transaction" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_send(200000000_i64, "KINGS")
        chain = block_factory.add_slow_block.chain
        utxo = UTXO.new(block_factory.blockchain)
        utxo.record(chain)

        result = utxo.valid_transactions?([transaction])
        result.failed.size.should eq(1)
        result.passed.size.should eq(0)
        result.failed.first.reason.should eq("Unable to send 2 KINGS to recipient because you do not have enough KINGS. You currently have: 0 KINGS and you are receiving: 0 KINGS from senders,  giving a total of: 0 KINGS")
      end
    end

    describe "burn_token" do
      it "burn token quantity should fail if user does not have enough token to burn in same block" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
          transaction2 = transaction_factory.make_burn_token("KINGS", 20_i64)

          utxo = UTXO.new(block_factory.add_slow_blocks(10).blockchain)
          transactions = [transaction1, transaction2]

          result = utxo.valid_transactions?(transactions)
          result.passed.size.should eq(1)
          result.passed.should eq([transaction1])
          result.failed.size.should eq(1)
          result.failed.map(&.reason).should eq(["Unable to burn 0.0000002 KINGS because you do not have enough KINGS. You currently have: 0.0000001 KINGS"])
        end
      end

      it "burn token quantity should fail if user does not have enough token to burn in the db" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
          transaction2 = transaction_factory.make_burn_token("KINGS", 20_i64)
         
          utxo = UTXO.new(block_factory.add_slow_blocks(10).add_slow_block([transaction1]).blockchain)
          transactions = [transaction2]

          result = utxo.valid_transactions?(transactions)
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.map(&.reason).should eq(["Unable to burn 0.0000002 KINGS because you do not have enough KINGS. You currently have: 0.0000001 KINGS"])
        end
      end
    end

    describe "make send with other internal dApps in the same pending block" do
      it "failure: create token then send" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
          transaction2 = transaction_factory.make_send(50_i64, "KINGS")

          utxo = UTXO.new(block_factory.add_slow_blocks(10).blockchain)
          transactions = [transaction1, transaction2]

          result = utxo.valid_transactions?(transactions)
          result.passed.size.should eq(1)
          result.failed.size.should eq(1)
          result.failed.map(&.reason).should eq(["Unable to send 0.0000005 KINGS to recipient because you do not have enough KINGS. You currently have: 0.0000001 KINGS and you are receiving: 0 KINGS from senders,  giving a total of: 0.0000001 KINGS"])
        end
      end
      it "success: create token then send" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
          transaction2 = transaction_factory.make_send(5_i64, "KINGS")

          utxo = UTXO.new(block_factory.add_slow_blocks(10).blockchain)
          transactions = [transaction1, transaction2]

          result = utxo.valid_transactions?(transactions)
          result.passed.size.should eq(2)
          result.failed.size.should eq(0)
        end
      end
      it "failure: create, update token then send" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
          transaction2 = transaction_factory.make_update_token("KINGS", 10_i64)
          transaction3 = transaction_factory.make_send(50_i64, "KINGS")

          utxo = UTXO.new(block_factory.add_slow_blocks(10).blockchain)
          transactions = [transaction1, transaction2, transaction3]

          result = utxo.valid_transactions?(transactions)
          result.passed.size.should eq(2)
          result.failed.size.should eq(1)
          result.failed.map(&.reason).should eq(["Unable to send 0.0000005 KINGS to recipient because you do not have enough KINGS. You currently have: 0.0000002 KINGS and you are receiving: 0 KINGS from senders,  giving a total of: 0.0000002 KINGS"])
        end
      end
      it "success: create, update token then send" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
          transaction2 = transaction_factory.make_update_token("KINGS", 10_i64)
          transaction3 = transaction_factory.make_send(11_i64, "KINGS")

          utxo = UTXO.new(block_factory.add_slow_blocks(10).blockchain)
          transactions = [transaction1, transaction2, transaction3]

          result = utxo.valid_transactions?(transactions)
          result.passed.size.should eq(3)
          result.failed.size.should eq(0)
        end
      end
    end
  end

  describe "#define_rpc?" do
    describe "#amount" do
      it "should return the amount" do
        with_factory do |block_factory, _|
          block_factory.add_slow_blocks(6)
          recipient_address = block_factory.chain.last.transactions.first.recipients.first[:address]
          payload = {call: "amount", address: recipient_address, confirmation: 1, token: TOKEN_DEFAULT}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
            result.should eq("{\"confirmation\":0,\"pairs\":[{\"token\":\"AXNT\",\"amount\":\"71.99986848\"}]}")
          end
        end
      end
    end
  end

  it "should return fee when calling #Self.fee" do
    UTXO.fee("send").should eq(10000_i64)
  end
end
