# Copyright © 2017-2018 The Axentro Core developers
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
  describe "#get_for" do
    it "should get the amount for the supplied token and address" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_blocks(10).chain
        utxo = UTXO.new(block_factory.blockchain)
        utxo.record(chain)
        address = chain[1].transactions.first.recipients.first[:address]

        utxo.get_for(address, "AXNT").should eq(11999965560_i64)
      end
    end
  end

  describe "#get_for" do
    context "when address does not exist" do
      it "should return 0 when the number of blocks is less than confirmations and the address is not found" do
        with_factory do |block_factory, _|
          chain = block_factory.add_slow_block.chain
          utxo = UTXO.new(block_factory.blockchain)
          utxo.record(chain)

          utxo.get_for("address-does-not-exist", TOKEN_DEFAULT).should eq(0)
        end
      end

      it "should return address amount when the number of blocks is greater than confirmations and the address is not found" do
        with_factory do |block_factory, _|
          chain = block_factory.add_slow_blocks(10).chain
          utxo = UTXO.new(block_factory.blockchain)
          utxo.record(chain)

          utxo.get_for("address-does-not-exist", TOKEN_DEFAULT).should eq(0)
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

          utxo.get_for(address, "UNKNOWN").should eq(0)
        end
      end

      it "should return address amount when the number of blocks is greater than confirmations and the token is not found" do
        with_factory do |block_factory, _|
          chain = block_factory.add_slow_blocks(10).chain
          utxo = UTXO.new(block_factory.blockchain)
          utxo.record(chain)
          address = chain[1].transactions.first.recipients.first[:address]

          utxo.get_for(address, "UNKNOWN").should eq(0)
        end
      end
    end
  end

  describe "#get_pending" do
    it "should get pending transactions amount for the supplied address in the supplied transactions" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_block.chain
        utxo = UTXO.new(block_factory.blockchain)
        utxo.record(chain)

        transactions = chain.reject { |blk| blk.prev_hash == "genesis" }.flat_map { |blk| blk.transactions }
        address = chain[1].transactions.first.recipients.first[:address]
        expected_amount = transactions.flat_map { |txn| txn.recipients.select { |r| r[:address] == address } }.map { |x| x[:amount] }.sum * 2
        utxo.get_pending(address, transactions, TOKEN_DEFAULT).should eq(expected_amount)
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
        utxo.get_pending(address, transactions, TOKEN_DEFAULT).should eq(expected_amount)
      end
    end

    context "when chain is empty" do
      it "should get pending transactions amount for the supplied address when no transactions are supplied and the chain is empty" do
        with_factory do |block_factory, _|
          chain = [] of SlowBlock
          utxo = UTXO.new(block_factory.blockchain)
          utxo.record(chain)

          transactions = [] of Transaction
          address = "any-address"
          utxo.get_pending(address, transactions, TOKEN_DEFAULT).should eq(0)
        end
      end

      it "should get pending transactions when no transactions are supplied and the chain is empty and the address is unknown" do
        with_factory do |block_factory, _|
          chain = [] of SlowBlock
          utxo = UTXO.new(block_factory.blockchain)
          utxo.record(chain)

          transactions = [] of Transaction
          utxo.get_pending("address-does-not-exist", transactions, TOKEN_DEFAULT).should eq(0)
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
    it "should always return true" do
      with_factory do |block_factory, _|
        utxo = UTXO.new(block_factory.blockchain)
        utxo.transaction_related?("whatever").should be_true
      end
    end
  end

  describe "#valid_transaction?" do
    it "should return true if valid transaction" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_send(100_i64)
        transaction2 = transaction_factory.make_send(200_i64)
        chain = block_factory.add_slow_blocks(10).chain
        utxo = UTXO.new(block_factory.blockchain)
        utxo.record(chain)
        utxo.valid_transaction?(transaction2, [transaction1]).should be_true
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
        expect_raises(Exception, "there must be 1 or less recipients") do
          utxo.valid_transaction?(transaction2, [transaction1])
        end
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
        expect_raises(Exception, "there must be 1 sender") do
          utxo.valid_transaction?(transaction2, [transaction1])
        end
      end
    end

    it "should raise an error if sender does not have enough tokens to afford the transaction" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_send(100000000_i64)
        transaction2 = transaction_factory.make_send(2000000000_i64)
        chain = block_factory.add_slow_blocks(1).chain
        utxo = UTXO.new(block_factory.blockchain)

        utxo.record(chain)
        expect_raises(Exception, "Unable to send 20 AXNT to recipient because you do not have enough AXNT. You currently have: 10.99989373 AXNT and you are receiving: 0 AXNT from senders,  giving a total of: 10.99989373 AXNT") do
          utxo.valid_transaction?(transaction2, [transaction1])
        end
      end
    end

    it "should raise an error if sender does not have enough custom tokens to afford the transaction" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_send(100000000_i64, "KINGS")
        transaction2 = transaction_factory.make_send(200000000_i64, "KINGS")
        chain = block_factory.add_slow_block.chain
        utxo = UTXO.new(block_factory.blockchain)
        utxo.record(chain)

        expect_raises(Exception, "Unable to send 2 KINGS to recipient because you do not have enough KINGS. You currently have: -1 KINGS and you are receiving: 0 KINGS from senders,  giving a total of: -1 KINGS") do
          utxo.valid_transaction?(transaction2, [transaction1])
        end
      end
    end
  end

  # describe "#calculate_for_transactions" do
  #   it "should return utxo for transactions with mixed tokens" do
  #     with_factory do |block_factory, transaction_factory|
  #       transaction1 = transaction_factory.make_send(100_i64, "KINGS")
  #       transaction2 = transaction_factory.make_send(200_i64)
  #       chain = block_factory.add_slow_block.chain
  #       utxo = UTXO.new(block_factory.blockchain)
  #       utxo.record(chain)

  #       expected1 =
  #         TokenQuantity.new(
  #           "KINGS",
  #           [AddressQuantity.new(transaction_factory.sender_wallet.address, -100_i64),
  #            AddressQuantity.new(transaction_factory.recipient_wallet.address, 100_i64)]
  #         )

  #       expected2 = TokenQuantity.new(
  #         TOKEN_DEFAULT,
  #         [AddressQuantity.new(transaction_factory.sender_wallet.address, -20200_i64),
  #          AddressQuantity.new(transaction_factory.recipient_wallet.address, 200_i64)]
  #       )

  #       result = utxo.calculate_for_transactions([transaction1, transaction2])
  #       result.first.should eq(expected1)
  #       result.last.should eq(expected2)
  #     end
  #   end
  # end

  # describe "#create_token" do
  #   it "should create a custom token" do
  #     with_factory do |block_factory, transaction_factory|
  #       chain = block_factory.add_slow_block.chain
  #       utxo = UTXO.new(block_factory.blockchain)
  #       utxo.record(chain)
  #       utxo.@utxo_internal.map { |tq| tq.name }.uniq.should eq([TOKEN_DEFAULT])
  #       utxo.create_token(transaction_factory.sender_wallet.address, 1200_i64, "KINGS")
  #       utxo.@utxo_internal.map { |tq| tq.name }.uniq.should eq([TOKEN_DEFAULT, "KINGS"])
  #     end
  #   end
  # end

  # describe "#clear" do
  #   it "should clear the internal transaction lists with #clear" do
  #     with_factory do |block_factory, _|
  #       chain = block_factory.add_slow_blocks(10).chain
  #       utxo = UTXO.new(block_factory.blockchain)
  #       utxo.record(chain)

  #       utxo.@utxo_internal.size.should eq(11)
  #       utxo.clear
  #       utxo.@utxo_internal.size.should eq(0)
  #     end
  #   end
  # end

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
