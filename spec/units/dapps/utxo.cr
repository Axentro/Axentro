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

require "./../../spec_helper"
require "./../utils"

include Sushi::Core
include Units::Utils
include Sushi::Core::DApps::BuildIn
include Sushi::Core::Controllers

describe UTXO do
  describe "#get_for" do
    it "should get the amount for the supplied token and address" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_blocks(10).chain
        utxo = UTXO.new(block_factory.blockchain)
        utxo.record(chain)
        address = chain[1].transactions.first.recipients.first[:address]

        utxo.get_for(address, utxo.@utxo_internal.reverse, "SUSHI").should eq(11999965560_i64)
      end
    end
  end
  describe "#record" do
    it "should record" do
      with_factory do |block_factory, transaction_factory|
        sender_wallet = block_factory.node_wallet

        recipient_wallet_1 = Wallet.from_json(Wallet.create(true).to_json)
        recipient_wallet_2 = Wallet.from_json(Wallet.create(true).to_json)
        recipient_wallet_3 = Wallet.from_json(Wallet.create(true).to_json)

        transactions1 = [
          transaction_factory.make_send(1, "SUSHI", sender_wallet, recipient_wallet_1),
          transaction_factory.make_send(1, "SUSHI", sender_wallet, recipient_wallet_2),
          transaction_factory.make_create_token("KINGS", 80_000_i64, sender_wallet, recipient_wallet_1),
          transaction_factory.make_create_token("FOO", 70_000_i64, sender_wallet, recipient_wallet_1),
        ]

        transactions2 = [
          transaction_factory.make_send(1, "SUSHI", sender_wallet, recipient_wallet_1),
          transaction_factory.make_send(1, "SUSHI", sender_wallet, recipient_wallet_2),
        ]

        transactions3 = [
          transaction_factory.make_send(1, "KINGS", sender_wallet, recipient_wallet_1),
          transaction_factory.make_send(1, "KINGS", sender_wallet, recipient_wallet_2),
          transaction_factory.make_send(1, "FOO", sender_wallet, recipient_wallet_3),
        ]

        blockchain = block_factory.add_slow_block.blockchain
        utxo = UTXO.new(blockchain)

        chain1 = block_factory.add_slow_block(transactions1).chain
        utxo.record(chain1)

        chain2 = block_factory.add_slow_block(transactions2).chain
        utxo.record(chain2)

        chain3 = block_factory.add_slow_block(transactions3).chain
        utxo.record(chain3)

        _utxo = utxo.@utxo_internal
        _utxo.size.should eq(9)

        _utxo[0].should eq(TokenQuantity.new("SUSHI", [] of AddressQuantity))
        _utxo[1].should eq(TokenQuantity.new("SUSHI", [AddressQuantity.new(block_factory.node_wallet.address, 1199999373_i64)]))

        _utxo[2].should eq(TokenQuantity.new("SUSHI", [
          AddressQuantity.new(block_factory.node_wallet.address, 2359978118_i64),
          AddressQuantity.new(recipient_wallet_1.address, 1_i64),
          AddressQuantity.new(recipient_wallet_2.address, 1_i64),
        ]))

        _utxo[3].should eq(TokenQuantity.new("KINGS", [
          AddressQuantity.new(block_factory.node_wallet.address, 80000_i64),
          AddressQuantity.new(recipient_wallet_1.address, 0_i64),
          AddressQuantity.new(recipient_wallet_2.address, 0_i64),
        ]))

        _utxo[4].should eq(TokenQuantity.new("FOO", [
          AddressQuantity.new(block_factory.node_wallet.address, 70000_i64),
          AddressQuantity.new(recipient_wallet_1.address, 0_i64),
          AddressQuantity.new(recipient_wallet_2.address, 0_i64),
        ]))

        _utxo[5].should eq(TokenQuantity.new("SUSHI", [
          AddressQuantity.new(block_factory.node_wallet.address, 3559956237_i64),
          AddressQuantity.new(recipient_wallet_1.address, 2_i64),
          AddressQuantity.new(recipient_wallet_2.address, 2_i64),
        ]))

        _utxo[6].should eq(TokenQuantity.new("SUSHI", [
          AddressQuantity.new(block_factory.node_wallet.address, 4759923732_i64),
          AddressQuantity.new(recipient_wallet_1.address, 2_i64),
          AddressQuantity.new(recipient_wallet_2.address, 2_i64),
          AddressQuantity.new(recipient_wallet_3.address, 0_i64),
        ]))

        _utxo[7].should eq(TokenQuantity.new("KINGS", [
          AddressQuantity.new(block_factory.node_wallet.address, 80000_i64),
          AddressQuantity.new(recipient_wallet_1.address, 1_i64),
          AddressQuantity.new(recipient_wallet_2.address, 1_i64),
          AddressQuantity.new(recipient_wallet_3.address, 0_i64),
        ]))

        _utxo[8].should eq(TokenQuantity.new("FOO", [
          AddressQuantity.new(block_factory.node_wallet.address, 70000_i64),
          AddressQuantity.new(recipient_wallet_1.address, 0_i64),
          AddressQuantity.new(recipient_wallet_2.address, 0_i64),
          AddressQuantity.new(recipient_wallet_3.address, 1_i64),
        ]))
      end
    end
  end
  describe "#get" do
    it "should return 0 when the number of blocks is less than confirmations" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_block.chain
        utxo = UTXO.new(block_factory.blockchain)
        utxo.record(chain)

        address = chain[1].transactions.first.recipients.first[:address]
        utxo.get(address, TOKEN_DEFAULT, 10).should eq(0)
      end
    end

    it "should return address amount when the number of blocks is greater than confirmations" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_blocks(10).chain
        utxo = UTXO.new(block_factory.blockchain)
        utxo.record(chain)

        address = chain[1].transactions.first.recipients.first[:address]
        expected_amount = chain[1].transactions[0].recipients[0]["amount"]

        utxo.get(address, TOKEN_DEFAULT, 10).should eq(expected_amount)
      end
    end

    context "when address does not exist" do
      it "should return 0 when the number of blocks is less than confirmations and the address is not found" do
        with_factory do |block_factory, _|
          chain = block_factory.add_slow_block.chain
          utxo = UTXO.new(block_factory.blockchain)
          utxo.record(chain)

          utxo.get("address-does-not-exist", TOKEN_DEFAULT, 1).should eq(0)
        end
      end

      it "should return address amount when the number of blocks is greater than confirmations and the address is not found" do
        with_factory do |block_factory, _|
          chain = block_factory.add_slow_blocks(10).chain
          utxo = UTXO.new(block_factory.blockchain)
          utxo.record(chain)

          utxo.get("address-does-not-exist", TOKEN_DEFAULT, 1).should eq(0)
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

          utxo.get(address, "UNKNOWN", 1).should eq(0)
        end
      end

      it "should return address amount when the number of blocks is greater than confirmations and the token is not found" do
        with_factory do |block_factory, _|
          chain = block_factory.add_slow_blocks(10).chain
          utxo = UTXO.new(block_factory.blockchain)
          utxo.record(chain)
          address = chain[1].transactions.first.recipients.first[:address]

          utxo.get(address, "UNKNOWN", 1).should eq(0)
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
        expect_raises(Exception, "Unable to send 20 to recipient because you do not have enough. Current tokens: 10.99989373 + 0") do
          utxo.valid_transaction?(transaction2, [transaction1])
        end
      end
    end

    it "should raise an error if sender does not have enough default tokens to afford the transaction" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_send(1000000_i64, "KINGS")
        transaction2 = transaction_factory.make_send(2000000_i64, "KINGS")
        chain = block_factory.add_slow_block.chain
        utxo = UTXO.new(block_factory.blockchain)

        utxo.record(chain)
        expect_raises(Exception, "Unable to send 0.02 to recipient because you do not have enough. Current tokens: -0.01 + 0") do
          utxo.valid_transaction?(transaction2, [transaction1])
        end
      end
    end
  end

  describe "#calculate_for_transactions" do
    it "should return utxo for transactions with mixed tokens" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_send(100_i64, "KINGS")
        transaction2 = transaction_factory.make_send(200_i64)
        chain = block_factory.add_slow_block.chain
        utxo = UTXO.new(block_factory.blockchain)
        utxo.record(chain)

        expected1 =
          TokenQuantity.new(
            "KINGS",
            [AddressQuantity.new(transaction_factory.sender_wallet.address, -100_i64),
             AddressQuantity.new(transaction_factory.recipient_wallet.address, 100_i64)]
          )

        expected2 = TokenQuantity.new(
          TOKEN_DEFAULT,
          [AddressQuantity.new(transaction_factory.sender_wallet.address, -20200_i64),
           AddressQuantity.new(transaction_factory.recipient_wallet.address, 200_i64)]
        )

        result = utxo.calculate_for_transactions([transaction1, transaction2])
        result.first.should eq(expected1)
        result.last.should eq(expected2)
      end
    end
  end

  describe "#create_token" do
    it "should create a custom token" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.add_slow_block.chain
        utxo = UTXO.new(block_factory.blockchain)
        utxo.record(chain)
        utxo.@utxo_internal.map { |tq| tq.name }.uniq.should eq([TOKEN_DEFAULT])
        utxo.create_token(transaction_factory.sender_wallet.address, 1200_i64, "KINGS")
        utxo.@utxo_internal.map { |tq| tq.name }.uniq.should eq([TOKEN_DEFAULT, "KINGS"])
      end
    end
  end

  describe "#clear" do
    it "should clear the internal transaction lists with #clear" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_blocks(10).chain
        utxo = UTXO.new(block_factory.blockchain)
        utxo.record(chain)

        utxo.@utxo_internal.size.should eq(11)
        utxo.clear
        utxo.@utxo_internal.size.should eq(0)
      end
    end
  end

  describe "#define_rpc?" do
    describe "#amount" do
      it "should return the unconfirmed amount" do
        with_factory do |block_factory, _|
          block_factory.add_slow_blocks(10)
          recipient_address = block_factory.chain.last.transactions.first.recipients.first[:address]
          payload = {call: "amount", address: recipient_address, confirmation: 5, token: TOKEN_DEFAULT}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
            result.should eq("{\"confirmation\":5,\"pairs\":[{\"token\":\"SUSHI\",\"amount\":\"71.99986848\"}]}")
          end
        end
      end

      it "should return the confirmed amount" do
        with_factory do |block_factory, _|
          block_factory.add_slow_blocks(10)
          recipient_address = block_factory.chain.last.transactions.first.recipients.first[:address]
          payload = {call: "amount", address: recipient_address, confirmation: 10, token: TOKEN_DEFAULT}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
            result.should eq(%{{"confirmation":10,"pairs":[{"token":"SUSHI","amount":"11.99999373"}]}})
          end
        end
      end
    end
  end

  it "should return fee when calling #Self.fee" do
    UTXO.fee("send").should eq(10000_i64)
  end

  STDERR.puts "< dApps::UTXO"
end
