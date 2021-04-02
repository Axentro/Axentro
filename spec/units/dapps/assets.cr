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

describe AssetComponent do
  it "should perform #setup" do
    with_factory do |block_factory, _|
      component = AssetComponent.new(block_factory.add_slow_block.blockchain)
      component.setup.should be_nil
    end
  end

  it "should perform #transaction_actions" do
    with_factory do |block_factory, _|
      component = AssetComponent.new(block_factory.add_slow_block.blockchain)
      component.transaction_actions.should eq(["create_asset", "update_asset", "lock_asset", "send_asset"])
    end
  end

  describe "#transaction_related?" do
    it "should return true when action is related" do
      DApps::ASSET_ACTIONS.each do |action|
        with_factory do |block_factory, _|
          component = AssetComponent.new(block_factory.add_slow_block.blockchain)
          component.transaction_related?(action).should be_true
        end
      end
    end
    it "should return false when action is not related" do
      with_factory do |block_factory, _|
        component = AssetComponent.new(block_factory.add_slow_block.blockchain)
        component.transaction_related?("unrelated").should be_false
      end
    end
  end

  describe "#valid_transaction?" do
    describe "create_asset" do
      it "should pass when valid transaction" do
        with_factory do |block_factory, transaction_factory|
          asset_id = Asset.create_id
          transaction = transaction_factory.make_create_asset(a_quick_asset(asset_id))
          chain = block_factory.add_slow_blocks(10).chain
          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction])
          result.passed.size.should eq(1)
          result.failed.size.should eq(0)
          result.passed.should eq([transaction])
        end
      end

      it "asset must be exactly 1 asset" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [] of Transaction::Asset
          )
          chain = block_factory.add_slow_blocks(10).chain
          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("a transaction must have exactly 1 asset for 'create_asset'")
        end
      end

      it "asset -> asset_id must be correct length" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new("123", "name", "description", "media_location", "media_hash", 1, "terms", 1, __timestamp)]
          )
          chain = block_factory.add_slow_blocks(10).chain
          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset_id must be length of 64 for 'create_asset'")
        end
      end

      it "asset -> quantity must be 1 or more" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id = Transaction::Asset.create_id
          transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 0, "terms", 1, __timestamp)]
          )
          chain = block_factory.add_slow_blocks(10).chain
          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset quantity must be 1 or more for 'create_asset' with asset_id: #{asset_id}")
        end
      end

      it "asset -> asset_id must not already exist (when in same transaction batch)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id = Transaction::Asset.create_id
          transaction1 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", 1, __timestamp)]
          )
          transaction2 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", 1, __timestamp)]
          )
          chain = block_factory.add_slow_blocks(10).chain
          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction1, transaction2])
          result.passed.size.should eq(1)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset_id must not already exist (asset_id: #{asset_id}) 'create_asset'")
        end
      end

      it "asset -> asset_id must not already exist (when already in the db)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id = Transaction::Asset.create_id
          transaction1 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", 1, __timestamp)]
          )
          transaction2 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", 1, __timestamp)]
          )
          block_factory.add_slow_block([transaction1]).add_slow_blocks(4)

          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction2])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset_id must not already exist (asset_id: #{asset_id}) 'create_asset'")
        end
      end

      it "asset -> asset media_location must be unique and not already exist - unless empty (when in same transaction batch)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id_1 = Transaction::Asset.create_id
          asset_id_2 = Transaction::Asset.create_id
          transaction1 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", "media_hash1", 1, "terms", 1, __timestamp)]
          )
          transaction2 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_2, "name", "description", "media_location", "media_hash2", 1, "terms", 1, __timestamp)]
          )
          chain = block_factory.add_slow_blocks(10).chain
          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction1, transaction2])
          result.passed.size.should eq(1)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset media_location must not already exist (asset_id: #{asset_id_2}, media_location: media_location) 'create_asset'")
        end
      end

      it "asset -> asset media_location must be unique and not already exist - unless empty (when already in the db)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id_1 = Transaction::Asset.create_id
          asset_id_2 = Transaction::Asset.create_id
          transaction1 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", "media_hash1", 1, "terms", 1, __timestamp)]
          )
          transaction2 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_2, "name", "description", "media_location", "media_hash2", 1, "terms", 1, __timestamp)]
          )
          block_factory.add_slow_blocks(2).add_slow_block([transaction1]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction2])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset media_location must not already exist (asset_id: #{asset_id_2}, media_location: media_location) 'create_asset'")
        end
      end

      it "asset -> asset media_location can be empty" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id_1 = Transaction::Asset.create_id
          transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "", "media_hash1", 1, "terms", 1, __timestamp)]
          )

          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction])
          result.passed.size.should eq(1)
          result.failed.size.should eq(0)
        end
      end

      it "asset -> asset_hash must be unique and not already exist - unless empty (when in same transaction batch)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id_1 = Transaction::Asset.create_id
          asset_id_2 = Transaction::Asset.create_id
          transaction1 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location1", "media_hash", 1, "terms", 1, __timestamp)]
          )
          transaction2 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_2, "name", "description", "media_location2", "media_hash", 1, "terms", 1, __timestamp)]
          )
          chain = block_factory.add_slow_blocks(10).chain
          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction1, transaction2])
          result.passed.size.should eq(1)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset media_hash must not already exist (asset_id: #{asset_id_2}, media_hash: media_hash) 'create_asset'")
        end
      end

      it "asset -> asset_hash must be unique and not already exist - unless empty (when already in the db)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id_1 = Transaction::Asset.create_id
          asset_id_2 = Transaction::Asset.create_id
          transaction1 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location1", "media_hash", 1, "terms", 1, __timestamp)]
          )
          transaction2 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_2, "name", "description", "media_location2", "media_hash", 1, "terms", 1, __timestamp)]
          )
          block_factory.add_slow_blocks(2).add_slow_block([transaction1]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction2])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset media_hash must not already exist (asset_id: #{asset_id_2}, media_hash: media_hash) 'create_asset'")
        end
      end

      it "asset -> asset_hash can be empty" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id_1 = Transaction::Asset.create_id
          transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", "", 1, "terms", 1, __timestamp)]
          )

          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction])
          result.passed.size.should eq(1)
          result.failed.size.should eq(0)
        end
      end

      it "transaction -> senders must be 1" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id_1 = Transaction::Asset.create_id
          transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [] of Transaction::Sender,
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", "", 1, "terms", 1, __timestamp)]
          )

          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("senders can only be 1 for asset action")
        end
      end

      it "transaction -> recipients must be 1" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id_1 = Transaction::Asset.create_id
          transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [] of Transaction::Recipient,
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", "", 1, "terms", 1, __timestamp)]
          )

          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("number of specified recipients must be 1 for 'create_asset'")
        end
      end

      it "transaction -> sender and recipient must be the sender address" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet
          asset_id_1 = Transaction::Asset.create_id
          transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(recipient_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", "", 1, "terms", 1, __timestamp)]
          )

          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("address mismatch for 'create_asset'. sender: #{sender_wallet.address}, recipient: #{recipient_wallet.address}")
        end
      end

      it "transaction -> token must not be empty" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet
          asset_id_1 = Transaction::Asset.create_id
          transaction = transaction_factory.make_asset(
            "",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", "", 1, "terms", 1, __timestamp)]
          )

          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("token must not be empty")
        end
      end

      it "transaction -> amount must be 0" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet
          asset_id_1 = Transaction::Asset.create_id
          transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 100_i64, 0_i64)],
            [a_recipient(sender_wallet, 100_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", "", 1, "terms", 1, __timestamp)]
          )

          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("amount must be 0 for action: create_asset")
        end
      end

      it "transaction -> fee must be 0" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet
          asset_id_1 = Transaction::Asset.create_id
          transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 100_i64, 200_i64)],
            [a_recipient(sender_wallet, 100_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", "", 1, "terms", 1, __timestamp)]
          )

          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("amount must be 0 for action: create_asset")
        end
      end
    end
  end
end
