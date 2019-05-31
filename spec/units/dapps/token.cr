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

describe Token do
  it "should perform #setup" do
    with_factory do |block_factory, _|
      token = Token.new(block_factory.add_block.blockchain)
      token.setup.should be_nil
    end
  end
  it "should perform #transaction_actions" do
    with_factory do |block_factory, _|
      token = Token.new(block_factory.add_block.blockchain)
      token.transaction_actions.should eq(["create_token"])
    end
  end
  describe "#transaction_related?" do
    it "should return true when action is related" do
      with_factory do |block_factory, _|
        token = Token.new(block_factory.add_block.blockchain)
        token.transaction_related?("create_token").should be_true
      end
    end
    it "should return false when action is not related" do
      with_factory do |block_factory, _|
        token = Token.new(block_factory.add_block.blockchain)
        token.transaction_related?("unrelated").should be_false
      end
    end
  end

  describe "#valid_transaction?" do
    it "should return true when valid transaction" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_create_token("KINGS", 10_i64)
        chain = block_factory.add_blocks(10).chain
        token = Token.new(block_factory.blockchain)
        token.valid_transaction?(transaction, chain.last.transactions).should be_true
      end
    end
    it "should raise an error when no senders" do
      with_factory do |block_factory, transaction_factory|
        senders = [a_sender(transaction_factory.sender_wallet, 10_i64, 1000_i64)]
        recipients = [] of Transaction::Recipient
        transaction = transaction_factory.make_create_token("KINGS", senders, recipients)
        chain = block_factory.add_blocks(10).chain
        token = Token.new(block_factory.blockchain)
        expect_raises(Exception, "number of specified recipients must be one for 'create_token'") do
          token.valid_transaction?(transaction, chain.last.transactions)
        end
      end
    end

    it "should raise address mismatch when sender address is different to recipient address" do
      with_factory do |block_factory, transaction_factory|
        senders = [a_sender(transaction_factory.sender_wallet, 10_i64, 1000_i64)]
        recipients = [a_recipient(transaction_factory.recipient_wallet, 10_i64)]
        transaction = transaction_factory.make_create_token("KINGS", senders, recipients)
        chain = block_factory.add_blocks(10).chain
        token = Token.new(block_factory.blockchain)
        expect_raises(Exception, "address mismatch for 'create_token'. sender: #{transaction_factory.sender_wallet.address}, recipient: #{transaction_factory.recipient_wallet.address}") do
          token.valid_transaction?(transaction, chain.last.transactions)
        end
      end
    end

    it "should raise amount mismatch when sender amount is different to recipient amount" do
      with_factory do |block_factory, transaction_factory|
        senders = [a_sender(transaction_factory.sender_wallet, 10_i64, 1000_i64)]
        recipients = [a_recipient(transaction_factory.sender_wallet, 20_i64)]
        transaction = transaction_factory.make_create_token("KINGS", senders, recipients)
        chain = block_factory.add_blocks(10).chain
        token = Token.new(block_factory.blockchain)
        expect_raises(Exception, "amount mismatch for 'create_token'. sender: 10, recipient: 20") do
          token.valid_transaction?(transaction, chain.last.transactions)
        end
      end
    end

    it "should raise an error if token name is invalid" do
      with_factory do |block_factory, transaction_factory|
        token_name = "Inv al $d"
        transaction = transaction_factory.make_create_token(token_name, 10_i64)
        chain = block_factory.add_blocks(10).chain
        token = Token.new(block_factory.blockchain)
        message = <<-RULE
        You token '#{token_name}' is not valid

        1. token name must contain only uppercase letters or numbers
        2. token name length must be between 1 and 20 characters
        RULE
        expect_raises(Exception, message) do
          token.valid_transaction?(transaction, chain.last.transactions)
        end
      end
    end

    it "should raise an error if the token already exists in previous transactions" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
        transaction2 = transaction_factory.make_create_token("KINGS", 10_i64)
        token = Token.new(block_factory.add_blocks(10).blockchain)
        expect_raises(Exception, "the token KINGS is already created") do
          token.valid_transaction?(transaction2, [transaction1])
        end
      end
    end

    it "should raise an error if the token already exists" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
        transaction2 = transaction_factory.make_create_token("KINGS", 10_i64)
        chain = block_factory.add_block([transaction1]).add_blocks(10).chain
        token = Token.new(block_factory.blockchain)
        token.record(chain)
        expect_raises(Exception, "the token KINGS is already created") do
          token.valid_transaction?(transaction2, [] of Transaction)
        end
      end
    end
  end

  describe "#valid_token_name?" do
    it "should return true when token name is valid" do
      with_factory do |block_factory, _|
        token = Token.new(block_factory.blockchain)
        token.valid_token_name?("KINGS").should be_true
      end
    end

    it "should raise an error with a message when " do
      with_factory do |block_factory, _|
        token_name = "kings"
        message = <<-RULE
        You token '#{token_name}' is not valid

        1. token name must contain only uppercase letters or numbers
        2. token name length must be between 1 and 20 characters
        RULE

        token = Token.new(block_factory.blockchain)
        expect_raises(Exception, message) do
          token.valid_token_name?(token_name)
        end
      end
    end

    it "should raise an error when domain name is longer than 20 characters" do
      with_factory do |block_factory, _|
        token = Token.new(block_factory.blockchain)
        expect_raises(Exception) do
          token.valid_token_name?("123456789012345678901.sc")
        end
      end
    end

    it "should raise an error when domain name contains empty spaces" do
      with_factory do |block_factory, _|
        token = Token.new(block_factory.blockchain)
        expect_raises(Exception) do
          token.valid_token_name?("K I N G S")
        end
      end
    end

    it "should work when using Self.valid_domain?" do
      Token.valid_token_name?("KINGS").should be_true
    end
  end

  it "should #record a chain" do
    with_factory do |block_factory, _|
      chain = block_factory.add_blocks(10).chain
      token = Token.new(block_factory.blockchain)
      token.record(chain).should eq(11)
    end
  end

  it "should #clear correctly" do
    with_factory do |block_factory, _|
      chain = block_factory.add_blocks(10).chain
      token = Token.new(block_factory.blockchain)
      token.record(chain).should eq(11)
      token.clear
      token.@tokens.should eq(["SUSHI"])
    end
  end

  describe "#define_rpc?" do
    describe "#token_list" do
      it "should list the tokens" do
        with_factory do |block_factory, _|
          payload = {call: "token_list"}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
            result.should eq("[\"SUSHI\"]")
          end
        end
      end
    end
  end
  STDERR.puts "< dApps::Token"
end
