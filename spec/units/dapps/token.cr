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

describe Token do
  it "should perform #setup" do
    with_factory do |block_factory, _|
      token = Token.new(block_factory.add_slow_block.blockchain)
      token.setup.should be_nil
    end
  end
  it "should perform #transaction_actions" do
    with_factory do |block_factory, _|
      token = Token.new(block_factory.add_slow_block.blockchain)
      token.transaction_actions.should eq(["create_token", "update_token", "lock_token", "burn_token"])
    end
  end
  describe "#transaction_related?" do
    it "should return true when action is related" do
      with_factory do |block_factory, _|
        token = Token.new(block_factory.add_slow_block.blockchain)
        token.transaction_related?("create_token").should be_true
      end
    end
    it "should return false when action is not related" do
      with_factory do |block_factory, _|
        token = Token.new(block_factory.add_slow_block.blockchain)
        token.transaction_related?("unrelated").should be_false
      end
    end
  end

  describe "#valid_transaction?" do
    it "should pass when valid transaction" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_create_token("KINGS", 10_i64)
        chain = block_factory.add_slow_blocks(10).chain
        token = Token.new(block_factory.blockchain)
        transactions = chain.last.transactions + [transaction]

        result = token.valid_transactions?(transactions)
        result.passed.size.should eq(1)
        result.failed.size.should eq(0)
        result.passed.should eq([transaction])
      end
    end

    it "should raise an error when no senders" do
      with_factory do |block_factory, transaction_factory|
        senders = [a_sender(transaction_factory.sender_wallet, 10_i64, 1000_i64)]
        recipients = [] of Transaction::Recipient
        transaction = transaction_factory.make_create_token("KINGS", senders, recipients, transaction_factory.sender_wallet)
        chain = block_factory.add_slow_blocks(10).chain
        token = Token.new(block_factory.blockchain)
        transactions = chain.last.transactions + [transaction]

        result = token.valid_transactions?(transactions)
        result.failed.size.should eq(1)
        result.passed.size.should eq(0)
        result.failed.first.reason.should eq("number of specified recipients must be 1 for 'create_token'")
      end
    end

    it "should raise an error when trying to create a token with the default AXNT name" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_create_token("AXNT", 10_i64)
        chain = block_factory.add_slow_blocks(10).chain
        token = Token.new(block_factory.blockchain)
        transactions = chain.last.transactions + [transaction]

        result = token.valid_transactions?(transactions)
        result.failed.size.should eq(1)
        result.passed.size.should eq(0)
        result.failed.first.reason.should eq("must not be the default token: AXNT")
      end
    end

    it "should raise an error when trying to update a token with the default AXNT name" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_update_token("AXNT", 10_i64)
        chain = block_factory.add_slow_blocks(10).chain
        token = Token.new(block_factory.blockchain)
        transactions = chain.last.transactions + [transaction]

        result = token.valid_transactions?(transactions)
        result.failed.size.should eq(1)
        result.passed.size.should eq(0)
        result.failed.first.reason.should eq("must not be the default token: AXNT")
      end
    end

    it "should raise an error when trying to lock a token with the default AXNT name" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_lock_token("AXNT")
        chain = block_factory.add_slow_blocks(10).chain
        token = Token.new(block_factory.blockchain)
        transactions = chain.last.transactions + [transaction]

        result = token.valid_transactions?(transactions)
        result.failed.size.should eq(1)
        result.passed.size.should eq(0)
        result.failed.first.reason.should eq("must not be the default token: AXNT")
      end
    end

    it "should raise address mismatch when sender address is different to recipient address" do
      with_factory do |block_factory, transaction_factory|
        senders = [a_sender(transaction_factory.sender_wallet, 10_i64, 1000_i64)]
        recipients = [a_recipient(transaction_factory.recipient_wallet, 10_i64)]
        transaction = transaction_factory.make_create_token("KINGS", senders, recipients, transaction_factory.sender_wallet)
        chain = block_factory.add_slow_blocks(10).chain
        token = Token.new(block_factory.blockchain)
        transactions = chain.last.transactions + [transaction]

        result = token.valid_transactions?(transactions)
        result.failed.size.should eq(1)
        result.passed.size.should eq(0)
        result.failed.first.reason.should eq("address mismatch for 'create_token'. sender: #{transaction_factory.sender_wallet.address}, recipient: #{transaction_factory.recipient_wallet.address}")
      end
    end

    it "should raise amount mismatch when sender amount is different to recipient amount" do
      with_factory do |block_factory, transaction_factory|
        senders = [a_sender(transaction_factory.sender_wallet, 10_i64, 1000_i64)]
        recipients = [a_recipient(transaction_factory.sender_wallet, 20_i64)]
        transaction = transaction_factory.make_create_token("KINGS", senders, recipients, transaction_factory.sender_wallet)
        chain = block_factory.add_slow_blocks(10).chain
        token = Token.new(block_factory.blockchain)
        transactions = chain.last.transactions + [transaction]

        result = token.valid_transactions?(transactions)
        result.failed.size.should eq(1)
        result.passed.size.should eq(0)
        result.failed.first.reason.should eq("amount mismatch for 'create_token'. sender: 10, recipient: 20")
      end
    end

    describe "invalid token name" do
      it "should raise an error if token name is totally invalid" do
        is_valid_token_name("Inv al $d")
      end

      it "should raise an error if token name is invalid with underscores" do
        is_valid_token_name("TO_KEN")
      end

      it "should reject a transaction if invalid token name" do
        with_factory do |block_factory, transaction_factory|
          transaction = transaction_factory.make_create_token("KIN_GS", 10_i64)
          blockchain = block_factory.blockchain
          block_factory.add_slow_blocks(10).add_slow_block([transaction])

          if reject = blockchain.rejects.find(transaction.id)
            reject.reason.should eq("You token 'KIN_GS' is not valid\n\n1. token name can only contain uppercase letters or numbers\n2. token name length must be between 1 and 20 characters")
          else
            fail "no rejects found"
          end
        end
      end
    end

    it "should raise an error if the token already exists in previous transactions" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
        transaction2 = transaction_factory.make_create_token("KINGS", 10_i64)
        token = Token.new(block_factory.add_slow_blocks(10).blockchain)
        transactions = [transaction1, transaction2]

        result = token.valid_transactions?(transactions)
        result.failed.size.should eq(1)
        result.passed.size.should eq(1)
        result.failed.first.reason.should eq("the token KINGS is already created")
      end
    end

    it "should raise an error if the token already exists" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
        transaction2 = transaction_factory.make_create_token("KINGS", 10_i64)
        chain = block_factory.add_slow_block([transaction1]).add_slow_blocks(10).chain
        token = Token.new(block_factory.blockchain)
        token.record(chain)
        transactions = [transaction2]

        result = token.valid_transactions?(transactions)
        result.failed.size.should eq(1)
        result.passed.size.should eq(0)
        result.failed.first.reason.should eq("the token KINGS is already created")
      end
    end

    it "create token quanity should fail if quantity is not a positive number greater than 0" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_create_token("KINGS", 0_i64)
        transaction2 = transaction_factory.make_create_token("KINGS2", -1_i64)
        token = Token.new(block_factory.add_slow_blocks(10).blockchain)
        transactions = [transaction1, transaction2]

        result = token.valid_transactions?(transactions)
        result.failed.size.should eq(2)
        result.passed.size.should eq(0)
        result.failed.map(&.reason).should eq(["invalid quantity: 0, must be a positive number greater than 0", "invalid quantity: -1, must be a positive number greater than 0"])
      end
    end

    describe "After a token is created only the token creator may create more quantity of this token" do
      it "update token quantity should pass when done by the token creator when create is same block" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
          transaction2 = transaction_factory.make_update_token("KINGS", 20_i64)
          token = Token.new(block_factory.add_slow_blocks(10).blockchain)
          transactions = [transaction1, transaction2]

          result = token.valid_transactions?(transactions)
          result.failed.size.should eq(0)
          result.passed.size.should eq(2)
          result.passed.should eq(transactions)
        end
      end

      it "update token quantity should pass when done by the token creator when create is already in the db" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
          transaction2 = transaction_factory.make_update_token("KINGS", 20_i64)
          token = Token.new(block_factory.add_slow_blocks(10).add_slow_block([transaction1]).blockchain)
          transactions = [transaction2]

          result = token.valid_transactions?(transactions)
          result.failed.size.should eq(0)
          result.passed.size.should eq(1)
          result.passed.should eq(transactions)
        end
      end

      it "update token quantity should fail if quantity is not a positive number greater than 0" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)

          transaction2 = transaction_factory.make_update_token("KINGS", 0_i64)
          transaction3 = transaction_factory.make_update_token("KINGS", -1_i64)
          token = Token.new(block_factory.add_slow_blocks(10).blockchain)
          transactions = [transaction1, transaction2, transaction3]

          result = token.valid_transactions?(transactions)
          result.failed.size.should eq(2)
          result.passed.size.should eq(1)
          result.passed.first.should eq(transaction1)
          result.failed.map(&.reason).should eq(["invalid quantity: 0, must be a positive number greater than 0", "invalid quantity: -1, must be a positive number greater than 0"])
        end
      end

      it "update token quantity should fail when done by not the creator when create is in the same block" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)

          # try update using a different wallet than the one that created the token
          transaction2 = transaction_factory.make_update_token("KINGS", 20_i64, transaction_factory.recipient_wallet)
          token = Token.new(block_factory.add_slow_blocks(10).blockchain)
          transactions = [transaction1, transaction2]

          result = token.valid_transactions?(transactions)
          result.failed.size.should eq(1)
          result.passed.size.should eq(1)
          result.passed.first.should eq(transaction1)
          result.failed.map(&.reason).should eq(["only the token creator can perform update token on existing token: KINGS"])
        end
      end

      it "update token quantity should fail when done by not the creator when create is already in the db" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)

          # try update using a different wallet than the one that created the token
          transaction2 = transaction_factory.make_update_token("KINGS", 20_i64, transaction_factory.recipient_wallet)
          token = Token.new(block_factory.add_slow_blocks(10).add_slow_block([transaction1]).blockchain)
          transactions = [transaction2]

          result = token.valid_transactions?(transactions)
          result.failed.size.should eq(1)
          result.passed.size.should eq(0)
          result.failed.map(&.reason).should eq(["only the token creator can perform update token on existing token: KINGS"])
        end
      end

      it "update token quantity should fail if no token exists" do
        with_factory do |block_factory, transaction_factory|
          transaction = transaction_factory.make_update_token("KINGS", 20_i64)
          token = Token.new(block_factory.add_slow_blocks(10).blockchain)
          transactions = [transaction]

          result = token.valid_transactions?(transactions)
          result.failed.size.should eq(1)
          result.passed.size.should eq(0)
          result.failed.map(&.reason).should eq(["the token KINGS does not exist, you must create it before attempting to perform update token"])
        end
      end
    end

    describe "The token creator may choose to lock the token meaning they cannot create any more of that token" do
      it "lock token should pass when done by the token creator when create is same block" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
          transaction2 = transaction_factory.make_lock_token("KINGS")
          token = Token.new(block_factory.add_slow_blocks(10).blockchain)
          transactions = [transaction1, transaction2]

          result = token.valid_transactions?(transactions)
          result.failed.size.should eq(0)
          result.passed.size.should eq(2)
          result.passed.should eq(transactions)
        end
      end

      it "lock token should pass when done by the token creator when create is already in the db" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
          transaction2 = transaction_factory.make_lock_token("KINGS")
          token = Token.new(block_factory.add_slow_blocks(10).add_slow_block([transaction1]).blockchain)
          transactions = [transaction2]

          result = token.valid_transactions?(transactions)
          result.failed.size.should eq(0)
          result.passed.size.should eq(1)
          result.passed.should eq(transactions)
        end
      end

      it "lock token should fail if amount if not 0" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
          transaction2 = transaction_factory.make_lock_token("KINGS", 20_i64)
          token = Token.new(block_factory.add_slow_blocks(10).blockchain)
          transactions = [transaction1, transaction2]

          result = token.valid_transactions?(transactions)
          result.failed.size.should eq(1)
          result.passed.size.should eq(1)
          result.failed.map(&.reason).should eq(["the sender amount must be 0 when locking the token: KINGS"])
        end
      end

      it "lock token should fail if token already locked in the same block" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
          transaction2 = transaction_factory.make_lock_token("KINGS")
          transaction3 = transaction_factory.make_lock_token("KINGS")
          token = Token.new(block_factory.add_slow_blocks(10).blockchain)
          transactions = [transaction1, transaction2, transaction3]

          result = token.valid_transactions?(transactions)
          result.failed.size.should eq(1)
          result.passed.size.should eq(2)
          result.failed.map(&.reason).should eq(["the token: KINGS is already locked"])
        end
      end

      it "lock token should fail if token already locked in the db" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
          transaction2 = transaction_factory.make_lock_token("KINGS")
          transaction3 = transaction_factory.make_lock_token("KINGS")
          token = Token.new(block_factory.add_slow_blocks(10).add_slow_block([transaction1, transaction2]).blockchain)
          transactions = [transaction3]

          result = token.valid_transactions?(transactions)
          result.failed.size.should eq(1)
          result.passed.size.should eq(0)
          result.failed.map(&.reason).should eq(["the token: KINGS is already locked"])
        end
      end

      it "lock token should fail when done by not the creator when create is in the same block" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)

          # try update using a different wallet than the one that created the token
          transaction2 = transaction_factory.make_lock_token("KINGS", 0_i64, transaction_factory.recipient_wallet)
          token = Token.new(block_factory.add_slow_blocks(10).blockchain)
          transactions = [transaction1, transaction2]

          result = token.valid_transactions?(transactions)
          result.failed.size.should eq(1)
          result.passed.size.should eq(1)
          result.passed.first.should eq(transaction1)
          result.failed.map(&.reason).should eq(["only the token creator can perform lock token on existing token: KINGS"])
        end
      end

      it "lock token should fail when done by not the creator when create is already in the db" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)

          # try update using a different wallet than the one that created the token
          transaction2 = transaction_factory.make_lock_token("KINGS", 0_i64, transaction_factory.recipient_wallet)
          token = Token.new(block_factory.add_slow_blocks(10).add_slow_block([transaction1]).blockchain)
          transactions = [transaction2]

          result = token.valid_transactions?(transactions)
          result.failed.size.should eq(1)
          result.passed.size.should eq(0)
          result.failed.map(&.reason).should eq(["only the token creator can perform lock token on existing token: KINGS"])
        end
      end

      it "lock token quantity should fail if no token exists" do
        with_factory do |block_factory, transaction_factory|
          transaction = transaction_factory.make_lock_token("KINGS")
          token = Token.new(block_factory.add_slow_blocks(10).blockchain)
          transactions = [transaction]

          result = token.valid_transactions?(transactions)
          result.failed.size.should eq(1)
          result.passed.size.should eq(0)
          result.failed.map(&.reason).should eq(["the token KINGS does not exist, you must create it before attempting to perform lock token"])
        end
      end

      it "update token quantity should fail if token is locked in the db" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
          transaction2 = transaction_factory.make_lock_token("KINGS")
          transaction3 = transaction_factory.make_update_token("KINGS", 20_i64)

          token = Token.new(block_factory.add_slow_blocks(10).add_slow_block([transaction1, transaction2]).blockchain)
          transactions = [transaction3]

          result = token.valid_transactions?(transactions)
          result.failed.size.should eq(1)
          result.passed.size.should eq(0)
          result.failed.map(&.reason).should eq(["the token: KINGS is locked and may no longer be updated"])
        end
      end

      it "update token quantity should fail if token is locked in the current transactions" do
        with_factory do |block_factory, transaction_factory|
          transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
          transaction2 = transaction_factory.make_lock_token("KINGS")
          transaction3 = transaction_factory.make_update_token("KINGS", 20_i64)

          token = Token.new(block_factory.add_slow_blocks(10).blockchain)
          transactions = [transaction1, transaction2, transaction3]

          result = token.valid_transactions?(transactions)
          result.failed.size.should eq(1)
          result.passed.size.should eq(2)
          result.failed.map(&.reason).should eq(["the token: KINGS is locked and may no longer be updated"])
        end
      end
    end

    # describe "At any time any user holding the token can choose to burn some or all of it that they hold" do
    it "burn token should pass when done by the token holder when create is same block" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
        transaction2 = transaction_factory.make_burn_token("KINGS", 5_i64)
        token = Token.new(block_factory.add_slow_blocks(10).blockchain)
        transactions = [transaction1, transaction2]

        result = token.valid_transactions?(transactions)
        result.failed.size.should eq(0)
        result.passed.size.should eq(2)
        result.passed.should eq(transactions)
      end
    end

    it "burn token should reduce the amount of token held by the user" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
        transaction2 = transaction_factory.make_update_token("KINGS", 10_i64)
        transaction3 = transaction_factory.make_burn_token("KINGS", 5_i64)
        block_factory.add_slow_blocks(10).add_slow_block([transaction1])

        before = block_factory.database.get_address_amount(block_factory.node_wallet.address)
        before.select(&.token.==("KINGS")).sum(&.amount).should eq(10_i64)

        block_factory.add_slow_block([transaction2, transaction3])

        after = block_factory.database.get_address_amount(block_factory.node_wallet.address)
        after.select(&.token.==("KINGS")).sum(&.amount).should eq(15_i64)
      end
    end

    it "burn token should pass when done by the token holder when create is already in the db" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)
        transaction2 = transaction_factory.make_burn_token("KINGS", 5_i64)
        token = Token.new(block_factory.add_slow_blocks(10).add_slow_block([transaction1]).blockchain)
        transactions = [transaction2]

        result = token.valid_transactions?(transactions)
        result.failed.size.should eq(0)
        result.passed.size.should eq(1)
        result.passed.should eq(transactions)
      end
    end

    it "burn token quantity should fail if quantity is not a positive number greater than 0" do
      with_factory do |block_factory, transaction_factory|
        transaction1 = transaction_factory.make_create_token("KINGS", 10_i64)

        transaction2 = transaction_factory.make_burn_token("KINGS", 0_i64)
        transaction3 = transaction_factory.make_burn_token("KINGS", -1_i64)
        token = Token.new(block_factory.add_slow_blocks(10).blockchain)
        transactions = [transaction1, transaction2, transaction3]

        result = token.valid_transactions?(transactions)
        result.failed.size.should eq(2)
        result.passed.size.should eq(1)
        result.passed.first.should eq(transaction1)
        result.failed.map(&.reason).should eq(["invalid quantity: 0, must be a positive number greater than 0", "invalid quantity: -1, must be a positive number greater than 0"])
      end
    end

    it "burn token quantity should fail if token they are trying to burn does not exist in the same block" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_burn_token("KINGS", 20_i64)
        token = Token.new(block_factory.add_slow_blocks(10).blockchain)
        transactions = [transaction]

        result = token.valid_transactions?(transactions)
        result.failed.size.should eq(1)
        result.passed.size.should eq(0)
        result.failed.map(&.reason).should eq(["the token KINGS does not exist, you must create it before attempting to perform burn token"])
      end
    end

    it "burn token quantity should fail if token they are trying to burn does not exist in the db" do
      with_factory do |block_factory, transaction_factory|
        transaction = transaction_factory.make_burn_token("KINGS", 20_i64)
        token = Token.new(block_factory.add_slow_blocks(10).blockchain)
        transactions = [transaction]

        result = token.valid_transactions?(transactions)
        result.failed.size.should eq(1)
        result.passed.size.should eq(0)
        result.failed.map(&.reason).should eq(["the token KINGS does not exist, you must create it before attempting to perform burn token"])
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

        1. token name can only contain uppercase letters or numbers
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
          token.valid_token_name?("123456789012345678901.ax")
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

  it "#record create any new tokens" do
    with_factory do |block_factory, transaction_factory|
      token_name = "NEW"
      transaction = transaction_factory.make_create_token(token_name, 10_i64)
      chain = block_factory.add_slow_blocks(10).add_slow_block([transaction]).chain
      token = Token.new(block_factory.blockchain)
      token.record(chain)
      block_factory.database.token_exists?(token_name).should be_true
    end
  end

  describe "#define_rpc?" do
    describe "#token_list" do
      it "should list the tokens" do
        with_factory do |block_factory, _|
          payload = {call: "token_list"}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
            result.should eq("[\"AXNT\"]")
          end
        end
      end
    end
  end
end

def is_valid_token_name(token_name)
  with_factory do |block_factory, transaction_factory|
    transaction = transaction_factory.make_create_token(token_name, 10_i64)
    chain = block_factory.add_slow_blocks(10).chain
    token = Token.new(block_factory.blockchain)
    message = <<-RULE
    You token '#{token_name}' is not valid

    1. token name can only contain uppercase letters or numbers
    2. token name length must be between 1 and 20 characters
    RULE
    transactions = chain.last.transactions + [transaction]

    result = token.valid_transactions?(transactions)
    result.failed.size.should eq(1)
    result.passed.size.should eq(0)
    result.failed.first.reason.should eq(message)
  end
end
