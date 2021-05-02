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
      component.transaction_actions.should eq(["create_asset", "update_asset", "send_asset"])
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
    describe "common to all asset actions" do
      it "transaction -> senders must be 1" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id_1 = Transaction::Asset.create_id
          transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [] of Transaction::Sender,
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", "", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
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
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", "", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
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
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", "", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
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
          asset_id_1 = Transaction::Asset.create_id
          transaction = transaction_factory.make_asset(
            "",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", "", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
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

          asset_id_1 = Transaction::Asset.create_id
          transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 100_i64, 0_i64)],
            [a_recipient(sender_wallet, 100_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", "", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
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
          asset_id_1 = Transaction::Asset.create_id
          transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 100_i64, 200_i64)],
            [a_recipient(sender_wallet, 100_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", "", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )

          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("amount must be 0 for action: create_asset")
        end
      end
    end

    describe "create_asset" do
      it "should pass when valid transaction" do
        with_factory do |block_factory, transaction_factory|
          asset_id = Asset.create_id
          transaction = transaction_factory.make_create_asset(a_quick_asset(asset_id))
          block_factory.add_slow_blocks(10)
          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction])
          result.passed.size.should eq(1)
          result.failed.size.should eq(0)
          result.passed.should eq([transaction])
        end
      end

      it "asset -> version should be 1" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id = Asset.create_id
          transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 2, __timestamp)]
          )

          block_factory.add_slow_blocks(10)
          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset version must be 1 for 'create_asset'")
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
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          transaction2 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          block_factory.add_slow_blocks(10)
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
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          transaction2 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
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
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", "media_hash1", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          transaction2 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_2, "name", "description", "media_location", "media_hash2", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          block_factory.add_slow_blocks(10)
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
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", "media_hash1", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          transaction2 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_2, "name", "description", "media_location", "media_hash2", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          block_factory.add_slow_blocks(2).add_slow_block([transaction1]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction2])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset media_location must not already exist (asset_id: #{asset_id_2}, media_location: media_location) 'create_asset'")
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
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location1", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          transaction2 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_2, "name", "description", "media_location2", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          block_factory.add_slow_blocks(10).chain
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
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location1", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          transaction2 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_2, "name", "description", "media_location2", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          block_factory.add_slow_blocks(2).add_slow_block([transaction1]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction2])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset media_hash must not already exist (asset_id: #{asset_id_2}, media_hash: media_hash) 'create_asset'")
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
            [Transaction::Asset.new(asset_id_1, "name", "description", "", "media_hash1", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )

          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction])
          result.passed.size.should eq(1)
          result.failed.size.should eq(0)
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
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", "", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )

          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction])
          result.passed.size.should eq(1)
          result.failed.size.should eq(0)
        end
      end
    end

    describe "create_asset and update_asset common validation" do
      it "asset must be exactly 1 asset" do
        ["create_asset", "update_asset"].each do |action|
          with_factory do |block_factory, transaction_factory|
            sender_wallet = transaction_factory.sender_wallet
            transaction = transaction_factory.make_asset(
              "AXNT",
              action,
              [a_sender(sender_wallet, 0_i64, 0_i64)],
              [a_recipient(sender_wallet, 0_i64)],
              [] of Transaction::Asset
            )
            block_factory.add_slow_blocks(10)
            component = AssetComponent.new(block_factory.blockchain)

            result = component.valid_transactions?([transaction])
            result.passed.size.should eq(0)
            result.failed.size.should eq(1)
            result.failed.first.reason.should eq("a transaction must have exactly 1 asset for '#{action}'")
          end
        end
      end

      it "asset -> asset_id must be correct length" do
        ["create_asset", "update_asset"].each do |action|
          with_factory do |block_factory, transaction_factory|
            sender_wallet = transaction_factory.sender_wallet
            transaction = transaction_factory.make_asset(
              "AXNT",
              action,
              [a_sender(sender_wallet, 0_i64, 0_i64)],
              [a_recipient(sender_wallet, 0_i64)],
              [Transaction::Asset.new("123", "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
            )
            block_factory.add_slow_blocks(10)
            component = AssetComponent.new(block_factory.blockchain)

            result = component.valid_transactions?([transaction])
            result.passed.size.should eq(0)
            result.failed.size.should eq(1)
            result.failed.first.reason.should eq("asset_id must be length of 64 for '#{action}'")
          end
        end
      end

      it "asset -> quantity must be 1 or more" do
        ["create_asset", "update_asset"].each do |action|
          with_factory do |block_factory, transaction_factory|
            sender_wallet = transaction_factory.sender_wallet
            asset_id = Transaction::Asset.create_id
            transaction = transaction_factory.make_asset(
              "AXNT",
              action,
              [a_sender(sender_wallet, 0_i64, 0_i64)],
              [a_recipient(sender_wallet, 0_i64)],
              [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 0, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
            )
            block_factory.add_slow_blocks(10)
            component = AssetComponent.new(block_factory.blockchain)

            result = component.valid_transactions?([transaction])
            result.passed.size.should eq(0)
            result.failed.size.should eq(1)
            result.failed.first.reason.should eq("asset quantity must be 1 or more for '#{action}' with asset_id: #{asset_id}")
          end
        end
      end
    end

    describe "update_asset" do
      it "should pass when valid update_asset transaction" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          block_factory.add_slow_block([create_transaction]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          update_transaction = transaction_factory.make_asset(
            "AXNT",
            "update_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "updated_name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 2, __timestamp)]
          )

          result = component.valid_transactions?([update_transaction])
          result.passed.size.should eq(1)
          result.failed.size.should eq(0)
        end
      end

      it "asset must already exist" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id = Transaction::Asset.create_id

          component = AssetComponent.new(block_factory.blockchain)

          update_transaction = transaction_factory.make_asset(
            "AXNT",
            "update_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "updated_name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 2, __timestamp)]
          )

          result = component.valid_transactions?([update_transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("cannot update asset with asset_id: #{asset_id} as asset with this id is not found")
        end
      end

      it "only asset owner can update_asset" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          non_owner_wallet = Wallet.from_json(Wallet.create(true).to_json)

          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name1", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )

          update_transaction_2 = transaction_factory.make_asset(
            "AXNT",
            "update_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "updated_name2", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 2, __timestamp)]
          )

          update_transaction_3 = transaction_factory.make_asset(
            "AXNT",
            "update_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "updated_name3", "updated_description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 3, __timestamp)]
          )

          block_factory.add_slow_block([create_transaction, update_transaction_2]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          update_transaction_4 = transaction_factory.make_asset(
            "AXNT",
            "update_asset",
            [a_sender(non_owner_wallet, 0_i64, 0_i64)],
            [a_recipient(non_owner_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "faker", "faker", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 4, __timestamp)]
          )

          result = component.valid_transactions?([update_transaction_3, update_transaction_4])
          result.passed.size.should eq(1)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("cannot update asset with asset_id: #{asset_id} as sender with address #{non_owner_wallet.address} does not own this asset (owned by: #{sender_wallet.address})")
        end
      end

      it "asset version should be next in sequence" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          block_factory.add_slow_block([create_transaction]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          update_transaction = transaction_factory.make_asset(
            "AXNT",
            "update_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "updated_name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 3, __timestamp)]
          )

          result = component.valid_transactions?([update_transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("expected asset version 2 not 3 as next in sequence for 'update_asset'")
        end
      end

      it "media_location should not exist unless it's for the asset that is being updated (in transaction batch)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id_1 = Transaction::Asset.create_id
          asset_id_2 = Transaction::Asset.create_id
          transaction1 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          transaction2 = transaction_factory.make_asset(
            "AXNT",
            "update_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 2, __timestamp)]
          )
          transaction3 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_2, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          block_factory.add_slow_blocks(10)
          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction1, transaction2, transaction3])
          result.passed.size.should eq(2)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset media_location must not already exist (asset_id: #{asset_id_2}, media_location: media_location) 'create_asset'")
        end
      end

      it "media_location should not exist unless it's for the asset that is being updated (in db)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id_1 = Transaction::Asset.create_id
          asset_id_2 = Transaction::Asset.create_id
          transaction1 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          transaction2 = transaction_factory.make_asset(
            "AXNT",
            "update_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          transaction3 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_2, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          block_factory.add_slow_blocks(2).add_slow_block([transaction1, transaction2]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction3])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset media_location must not already exist (asset_id: #{asset_id_2}, media_location: media_location) 'create_asset'")
        end
      end

      it "media_hash should not exist unless it's for the asset that is being updated (in transaction batch)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id_1 = Transaction::Asset.create_id
          asset_id_2 = Transaction::Asset.create_id
          transaction1 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location1", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          transaction2 = transaction_factory.make_asset(
            "AXNT",
            "update_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location2", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 2, __timestamp)]
          )
          transaction3 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_2, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          block_factory.add_slow_blocks(10)
          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction1, transaction2, transaction3])
          result.passed.size.should eq(2)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset media_hash must not already exist (asset_id: #{asset_id_2}, media_hash: media_hash) 'create_asset'")
        end
      end

      it "media_hash should not exist unless it's for the asset that is being updated (in db)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id_1 = Transaction::Asset.create_id
          asset_id_2 = Transaction::Asset.create_id
          transaction1 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location1", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          transaction2 = transaction_factory.make_asset(
            "AXNT",
            "update_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location2", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          transaction3 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_2, "name", "description", "media_location3", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          block_factory.add_slow_blocks(2).add_slow_block([transaction1, transaction2]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([transaction3])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset media_hash must not already exist (asset_id: #{asset_id_2}, media_hash: media_hash) 'create_asset'")
        end
      end

      it "cannot send fields with size greater than max size for name, description, media_location, media_hash, terms" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id_1 = Transaction::Asset.create_id
          asset_id_2 = Transaction::Asset.create_id
          asset_id_3 = Transaction::Asset.create_id
          asset_id_4 = Transaction::Asset.create_id

          long_value = "exceeds"*500

          # Create asset
          create_name_exceeds = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, long_value, "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )

          create_description_exceeds = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_2, "name", long_value, "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )

          create_media_location_exceeds = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_3, "name", "description", long_value, "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )

          create_media_hash_exceeds = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_4, "name", "description", "media_location", long_value, 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )

          create_terms_exceeds = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_4, "name", "description", "media_location", "media_hash", 1, long_value, AssetAccess::UNLOCKED, 1, __timestamp)]
          )

          # Update asset
          create_asset = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )

          update_name_exceeds = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, long_value, "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )

          update_description_exceeds = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name", long_value, "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )

          update_media_location_exceeds = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", long_value, "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )

          update_media_hash_exceeds = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", long_value, 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )

          update_terms_exceeds = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name", "description", "media_location", "media_hash", 1, long_value, AssetAccess::UNLOCKED, 1, __timestamp)]
          )

          component = AssetComponent.new(block_factory.blockchain)

          result = component.valid_transactions?([
            create_name_exceeds,
            create_description_exceeds,
            create_terms_exceeds,
            create_media_location_exceeds,
            create_media_hash_exceeds,
            create_asset,
            update_name_exceeds,
            update_description_exceeds,
            update_terms_exceeds,
            update_media_location_exceeds,
            update_media_hash_exceeds,
          ])

          result.passed.size.should eq(1)
          result.failed.size.should eq(10)
          result.failed.first.reason.should eq("asset name must not exceed 256 bytes, you have: 3500")
          result.failed[1].reason.should eq("asset description must not exceed 2048 bytes, you have: 3500")
          result.failed[2].reason.should eq("asset terms must not exceed 2048 bytes, you have: 3500")
          result.failed[3].reason.should eq("asset media_location must not exceed 2048 bytes, you have: 3500")
          result.failed[4].reason.should eq("asset media_hash must not exceed 512 bytes, you have: 3500")

          result.failed[5].reason.should eq("asset name must not exceed 256 bytes, you have: 3500")
          result.failed[6].reason.should eq("asset description must not exceed 2048 bytes, you have: 3500")
          result.failed[7].reason.should eq("asset terms must not exceed 2048 bytes, you have: 3500")
          result.failed[8].reason.should eq("asset media_location must not exceed 2048 bytes, you have: 3500")
          result.failed[9].reason.should eq("asset media_hash must not exceed 512 bytes, you have: 3500")
        end
      end

      it "cannot update asset if locked (in transaction batch)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )

          lock_transaction = transaction_factory.make_asset(
            "AXNT",
            "update_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "updated_name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 2, __timestamp)]
          )

          block_factory.add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          update_transaction = transaction_factory.make_asset(
            "AXNT",
            "update_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "attempt_to_update", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 3, __timestamp)]
          )

          result = component.valid_transactions?([create_transaction, lock_transaction, update_transaction])
          result.passed.size.should eq(2)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset is locked so no updates are possible for 'update_asset'")
        end
      end

      it "cannot update asset if locked (in db)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )

          lock_transaction = transaction_factory.make_asset(
            "AXNT",
            "update_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "updated_name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 2, __timestamp)]
          )

          block_factory.add_slow_block([create_transaction, lock_transaction]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          update_transaction = transaction_factory.make_asset(
            "AXNT",
            "update_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "attempt_to_update", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 3, __timestamp)]
          )

          result = component.valid_transactions?([update_transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset is locked so no updates are possible for 'update_asset'")
        end
      end
    end

    describe "lock_asset" do
      it "should pass when valid update_asset lock transaction (in transaction batch)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          block_factory.add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          lock_transaction = transaction_factory.make_asset(
            "AXNT",
            "update_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 2, __timestamp)]
          )

          result = component.valid_transactions?([create_transaction, lock_transaction])
          result.passed.size.should eq(2)
          result.failed.size.should eq(0)
        end
      end
      it "should pass when valid update_asset lock transaction (in db)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          block_factory.add_slow_block([create_transaction]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          lock_transaction = transaction_factory.make_asset(
            "AXNT",
            "update_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 2, __timestamp)]
          )

          result = component.valid_transactions?([lock_transaction])
          result.passed.size.should eq(1)
          result.failed.size.should eq(0)
        end
      end
    end

    # asset must be locked before sending (if quantity was more than 1 - and many wallets hold the asset - if not locked there would be contention over trying to update the asset)
    # this will mean changing how we find the current asset owner for update asset but send asset will need it as
    describe "send_asset" do
      it "should pass when valid send_asset transaction (in transaction batch)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet
          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 1, __timestamp)]
          )
          block_factory.add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          send_asset_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id)],
            [an_asset_recipient(recipient_wallet, asset_id)],
            [] of Transaction::Asset
          )

          result = component.valid_transactions?([create_transaction, send_asset_transaction])
          result.passed.size.should eq(2)
          result.failed.size.should eq(0)
        end
      end

      it "should pass when valid send_asset transaction (in db)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet
          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 1, __timestamp)]
          )
          block_factory.add_slow_block([create_transaction]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          send_asset_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id)],
            [an_asset_recipient(recipient_wallet, asset_id)],
            [] of Transaction::Asset
          )

          result = component.valid_transactions?([send_asset_transaction])
          result.passed.size.should eq(1)
          result.failed.size.should eq(0)
        end
      end

      # it "boop" do
      #   with_factory do |block_factory, transaction_factory|
      #     sender_wallet = transaction_factory.sender_wallet
      #     asset_id = Transaction::Asset.create_id

      #     create_transaction = transaction_factory.make_asset(
      #       "AXNT",
      #       "create_asset",
      #       [a_sender(sender_wallet, 0_i64, 0_i64)],
      #       [a_recipient(sender_wallet, 0_i64)],
      #       [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
      #     )

      #     update_transaction = transaction_factory.make_asset(
      #       "AXNT",
      #       "update_asset",
      #       [a_sender(sender_wallet, 0_i64, 0_i64)],
      #       [a_recipient(sender_wallet, 0_i64)],
      #       [Transaction::Asset.new(asset_id, "name1", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 2, __timestamp)]
      #     )

      #     update_transaction2 = transaction_factory.make_asset(
      #       "AXNT",
      #       "update_asset",
      #       [a_sender(sender_wallet, 0_i64, 0_i64)],
      #       [a_recipient(sender_wallet, 0_i64)],
      #       [Transaction::Asset.new(asset_id, "name1", "description", "media_location", "media_hash", 100, "terms", AssetAccess::UNLOCKED, 3, __timestamp)]
      #     )

      #     asset_id2 = Transaction::Asset.create_id
      #     create_transaction2 = transaction_factory.make_asset(
      #       "AXNT",
      #       "create_asset",
      #       [a_sender(sender_wallet, 0_i64, 0_i64)],
      #       [a_recipient(sender_wallet, 0_i64)],
      #       [Transaction::Asset.new(asset_id2, "name2", "description2", "media_location2", "media_hash2", 1, "terms2", AssetAccess::UNLOCKED, 1, __timestamp)]
      #     )

      #     block_factory.add_slow_block([create_transaction, update_transaction, create_transaction2, update_transaction2]).add_slow_blocks(2)

      #     pp block_factory.database.get_address_asset_amounts([sender_wallet.address])
      #   end
      # end

      it "asset must be locked in order to send_asset (in transaction batch)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet
          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          block_factory.add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          send_asset_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id)],
            [an_asset_recipient(recipient_wallet, asset_id)],
            [] of Transaction::Asset
          )

          result = component.valid_transactions?([create_transaction, send_asset_transaction])
          result.passed.size.should eq(1)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset must be locked in order to send asset #{asset_id}")
        end
      end

      it "asset must be locked in order to send_asset (in db)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet
          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )
          block_factory.add_slow_block([create_transaction]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          send_asset_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id)],
            [an_asset_recipient(recipient_wallet, asset_id)],
            [] of Transaction::Asset
          )

          result = component.valid_transactions?([send_asset_transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset must be locked in order to send asset #{asset_id}")
        end
      end

      it "asset_id must not be empty (sender)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet
          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 1, __timestamp)]
          )
          block_factory.add_slow_block([create_transaction]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          send_asset_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, nil)],
            [an_asset_recipient(recipient_wallet, asset_id)],
            [] of Transaction::Asset
          )

          result = component.valid_transactions?([send_asset_transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset_id must be supplied for both sender and recipient in order to send an asset")
        end
      end

      it "asset_id must not be empty (recipient)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet
          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 1, __timestamp)]
          )
          block_factory.add_slow_block([create_transaction]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          send_asset_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id)],
            [an_asset_recipient(recipient_wallet, nil)],
            [] of Transaction::Asset
          )

          result = component.valid_transactions?([send_asset_transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset_id must be supplied for both sender and recipient in order to send an asset")
        end
      end

      it "asset must be empty" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet
          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 1, __timestamp)]
          )
          block_factory.add_slow_block([create_transaction]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          send_asset_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id)],
            [an_asset_recipient(recipient_wallet, asset_id)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 1, __timestamp)]
          )

          result = component.valid_transactions?([send_asset_transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("The assets should be empty in the transaction for action: send_asset")
        end
      end

      it "asset_quantity should be 1 or more (sender)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet
          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 1, __timestamp)]
          )
          block_factory.add_slow_block([create_transaction]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          send_asset_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id, 0)],
            [an_asset_recipient(recipient_wallet, asset_id, 0)],
            [] of Transaction::Asset
          )

          result = component.valid_transactions?([send_asset_transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset_quantity must be 1 or more for both sender and recipient in order to send an asset")
        end
      end

      it "asset_quantity should be 1 or more (recipient)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet
          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 1, __timestamp)]
          )
          block_factory.add_slow_block([create_transaction]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          send_asset_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id, 1)],
            [an_asset_recipient(recipient_wallet, asset_id, 0)],
            [] of Transaction::Asset
          )

          result = component.valid_transactions?([send_asset_transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset_quantity must be 1 or more for both sender and recipient in order to send an asset")
        end
      end

      it "asset_quantity should not be nil" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet
          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 1, __timestamp)]
          )
          block_factory.add_slow_block([create_transaction]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          send_asset_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id, nil)],
            [an_asset_recipient(recipient_wallet, asset_id, 1)],
            [] of Transaction::Asset
          )

          result = component.valid_transactions?([send_asset_transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset_quantity must be 1 or more for both sender and recipient in order to send an asset (was nil)")
        end
      end

      it "asset_quantity should not be the same for recipient and sender" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet
          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 1, __timestamp)]
          )
          block_factory.add_slow_block([create_transaction]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          send_asset_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id, 2)],
            [an_asset_recipient(recipient_wallet, asset_id, 1)],
            [] of Transaction::Asset
          )

          result = component.valid_transactions?([send_asset_transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("asset_quantity must be the same for both sender and recipient in order to send an asset")
        end
      end

      it "cannot send an asset that you do not own (in transaction batch)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet
          non_owner_wallet = Wallet.from_json(Wallet.create(true).to_json)

          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 1, __timestamp)]
          )

          component = AssetComponent.new(block_factory.blockchain)

          send_asset_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(non_owner_wallet, asset_id, 2)],
            [an_asset_recipient(recipient_wallet, asset_id, 2)],
            [] of Transaction::Asset
          )

          result = component.valid_transactions?([create_transaction, send_asset_transaction])
          result.passed.size.should eq(1)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("you have 0 quantity of asset: #{asset_id} so you cannot send 2")
        end
      end

      it "cannot send an asset that you do not own (in db)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet
          non_owner_wallet = Wallet.from_json(Wallet.create(true).to_json)

          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 1, __timestamp)]
          )

          block_factory.add_slow_block([create_transaction]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          send_asset_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(non_owner_wallet, asset_id, 2)],
            [an_asset_recipient(recipient_wallet, asset_id, 2)],
            [] of Transaction::Asset
          )

          result = component.valid_transactions?([send_asset_transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("you have 0 quantity of asset: #{asset_id} so you cannot send 2")
        end
      end

      it "cannot send an asset quantity if you don't have enough (in transaction batch)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet

          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 1, __timestamp)]
          )

          component = AssetComponent.new(block_factory.blockchain)

          send_asset_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id, 2)],
            [an_asset_recipient(recipient_wallet, asset_id, 2)],
            [] of Transaction::Asset
          )

          result = component.valid_transactions?([create_transaction, send_asset_transaction])
          result.passed.size.should eq(1)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("you have 1 quantity of asset: #{asset_id} so you cannot send 2")
        end
      end

      it "cannot send an asset quantity if you don't have enough (in db)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet

          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 1, __timestamp)]
          )

          block_factory.add_slow_block([create_transaction]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          send_asset_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id, 2)],
            [an_asset_recipient(recipient_wallet, asset_id, 2)],
            [] of Transaction::Asset
          )

          result = component.valid_transactions?([send_asset_transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("you have 1 quantity of asset: #{asset_id} so you cannot send 2")
        end
      end

      it "cannot send an asset quantity if you don't have enough after sending once already (in transaction batch)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet

          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 1, __timestamp)]
          )

          component = AssetComponent.new(block_factory.blockchain)

          send_asset_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id, 1)],
            [an_asset_recipient(recipient_wallet, asset_id, 1)],
            [] of Transaction::Asset
          )

          send_asset_transaction_2 = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id, 1)],
            [an_asset_recipient(recipient_wallet, asset_id, 1)],
            [] of Transaction::Asset
          )

          result = component.valid_transactions?([create_transaction, send_asset_transaction, send_asset_transaction_2])
          result.passed.size.should eq(2)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("you have 0 quantity of asset: #{asset_id} so you cannot send 1")
        end
      end

      it "cannot send an asset quantity if you don't have enough after sending once already (in db)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet

          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 1, __timestamp)]
          )

          send_asset_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id, 1)],
            [an_asset_recipient(recipient_wallet, asset_id, 1)],
            [] of Transaction::Asset
          )

          block_factory.add_slow_block([create_transaction, send_asset_transaction]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          send_asset_transaction_2 = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id, 1)],
            [an_asset_recipient(recipient_wallet, asset_id, 1)],
            [] of Transaction::Asset
          )

          result = component.valid_transactions?([send_asset_transaction_2])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("you have 0 quantity of asset: #{asset_id} so you cannot send 1")
        end
      end

      # specs about sending to self
      it "send to self when you have a quantity available (in transaction batch)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet

          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 1, __timestamp)]
          )

          component = AssetComponent.new(block_factory.blockchain)

          send_asset_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id, 1)],
            [an_asset_recipient(sender_wallet, asset_id, 1)],
            [] of Transaction::Asset
          )

          send_asset_transaction_2 = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id, 2)],
            [an_asset_recipient(recipient_wallet, asset_id, 2)],
            [] of Transaction::Asset
          )

          result = component.valid_transactions?([create_transaction, send_asset_transaction, send_asset_transaction_2])
          result.passed.size.should eq(2)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("you have 1 quantity of asset: #{asset_id} so you cannot send 2")
        end
      end

      it "send to self when you have a quantity available (in db)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet

          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 1, __timestamp)]
          )

          send_asset_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id, 1)],
            [an_asset_recipient(sender_wallet, asset_id, 1)],
            [] of Transaction::Asset
          )

          block_factory.add_slow_block([create_transaction, send_asset_transaction]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          send_asset_transaction_2 = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id, 2)],
            [an_asset_recipient(recipient_wallet, asset_id, 2)],
            [] of Transaction::Asset
          )

          result = component.valid_transactions?([send_asset_transaction_2])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("you have 1 quantity of asset: #{asset_id} so you cannot send 2")
        end
      end

      it "send to self when you have no quantity available (in transaction batch)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          non_owner_wallet = Wallet.from_json(Wallet.create(true).to_json)

          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 1, __timestamp)]
          )

          component = AssetComponent.new(block_factory.blockchain)

          send_asset_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(non_owner_wallet, asset_id, 1)],
            [an_asset_recipient(non_owner_wallet, asset_id, 1)],
            [] of Transaction::Asset
          )

          result = component.valid_transactions?([create_transaction, send_asset_transaction])
          result.passed.size.should eq(1)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("you have 0 quantity of asset: #{asset_id} so you cannot send 1")
        end
      end

      it "send to self when you have no quantity available (in db)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          non_owner_wallet = Wallet.from_json(Wallet.create(true).to_json)

          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 1, __timestamp)]
          )

          block_factory.add_slow_block([create_transaction]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          send_asset_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(non_owner_wallet, asset_id, 1)],
            [an_asset_recipient(non_owner_wallet, asset_id, 1)],
            [] of Transaction::Asset
          )

          result = component.valid_transactions?([send_asset_transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("you have 0 quantity of asset: #{asset_id} so you cannot send 1")
        end
      end

      # specs where quantity is updated before lock and send (in case getting more than 1 version of asset)
      it "send to recipient after quantity is updated (in transaction batch)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet

          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )

          component = AssetComponent.new(block_factory.blockchain)

          update_quantity_transaction_1 = transaction_factory.make_asset(
            "AXNT",
            "update_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 2, "terms", AssetAccess::UNLOCKED, 2, __timestamp)]
          )

          update_quantity_transaction_2 = transaction_factory.make_asset(
            "AXNT",
            "update_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 3, "terms", AssetAccess::LOCKED, 3, __timestamp)]
          )

          send_asset_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id, 1)],
            [an_asset_recipient(sender_wallet, asset_id, 1)],
            [] of Transaction::Asset
          )

          send_asset_transaction_2 = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id, 4)],
            [an_asset_recipient(recipient_wallet, asset_id, 4)],
            [] of Transaction::Asset
          )

          result = component.valid_transactions?([create_transaction, update_quantity_transaction_1, update_quantity_transaction_2, send_asset_transaction, send_asset_transaction_2])
          result.passed.size.should eq(4)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("you have 3 quantity of asset: #{asset_id} so you cannot send 4")
        end
      end

      it "send to recipient after quantity is updated (in db)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet

          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )

          update_quantity_transaction_1 = transaction_factory.make_asset(
            "AXNT",
            "update_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 2, "terms", AssetAccess::UNLOCKED, 2, __timestamp)]
          )

          update_quantity_transaction_2 = transaction_factory.make_asset(
            "AXNT",
            "update_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 3, "terms", AssetAccess::LOCKED, 3, __timestamp)]
          )

          send_asset_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id, 1)],
            [an_asset_recipient(sender_wallet, asset_id, 1)],
            [] of Transaction::Asset
          )

          block_factory.add_slow_block([create_transaction, update_quantity_transaction_1, update_quantity_transaction_2, send_asset_transaction]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          send_asset_transaction_2 = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id, 4)],
            [an_asset_recipient(recipient_wallet, asset_id, 4)],
            [] of Transaction::Asset
          )

          result = component.valid_transactions?([send_asset_transaction_2])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("you have 3 quantity of asset: #{asset_id} so you cannot send 4")
        end
      end

      it "can send one of many assets to another recipient (in transaction batch)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet

          asset_id_1 = Transaction::Asset.create_id
          asset_id_2 = Transaction::Asset.create_id
          asset_id_3 = Transaction::Asset.create_id

          create_transaction_1 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name1", "description", "media_location1", "media_hash1", 1, "terms", AssetAccess::LOCKED, 1, __timestamp)]
          )

          create_transaction_2 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_2, "name2", "description", "media_location2", "media_hash2", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )

          create_transaction_3 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_3, "name3", "description", "media_location3", "media_hash3", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )

          component = AssetComponent.new(block_factory.blockchain)

          update_quantity_asset_2 = transaction_factory.make_asset(
            "AXNT",
            "update_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_2, "name2", "description", "media_location2", "media_hash2", 2, "terms", AssetAccess::LOCKED, 2, __timestamp)]
          )

          update_quantity_asset_3 = transaction_factory.make_asset(
            "AXNT",
            "update_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_3, "name3", "description", "media_location3", "media_hash3", 3, "terms", AssetAccess::LOCKED, 2, __timestamp)]
          )

          send_asset_1_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id_1, 1)],
            [an_asset_recipient(sender_wallet, asset_id_1, 1)],
            [] of Transaction::Asset
          )

          send_asset_2_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id_2, 1)],
            [an_asset_recipient(recipient_wallet, asset_id_2, 1)],
            [] of Transaction::Asset
          )

          send_asset_3_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id_3, 4)],
            [an_asset_recipient(recipient_wallet, asset_id_3, 4)],
            [] of Transaction::Asset
          )

          result = component.valid_transactions?([create_transaction_1, create_transaction_2, create_transaction_3, update_quantity_asset_2, update_quantity_asset_3, send_asset_1_transaction, send_asset_2_transaction, send_asset_3_transaction])
          result.passed.size.should eq(7)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("you have 3 quantity of asset: #{asset_id_3} so you cannot send 4")
        end
      end

      it "can send one of many assets to another recipient (in db)" do
        with_factory do |block_factory, transaction_factory|
          sender_wallet = transaction_factory.sender_wallet
          recipient_wallet = transaction_factory.recipient_wallet

          asset_id_1 = Transaction::Asset.create_id
          asset_id_2 = Transaction::Asset.create_id
          asset_id_3 = Transaction::Asset.create_id

          create_transaction_1 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_1, "name1", "description", "media_location1", "media_hash1", 1, "terms", AssetAccess::LOCKED, 1, __timestamp)]
          )

          create_transaction_2 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_2, "name2", "description", "media_location2", "media_hash2", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )

          create_transaction_3 = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_3, "name3", "description", "media_location3", "media_hash3", 1, "terms", AssetAccess::UNLOCKED, 1, __timestamp)]
          )

          update_quantity_asset_2 = transaction_factory.make_asset(
            "AXNT",
            "update_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_2, "name2", "description", "media_location2", "media_hash2", 2, "terms", AssetAccess::LOCKED, 2, __timestamp)]
          )

          update_quantity_asset_3 = transaction_factory.make_asset(
            "AXNT",
            "update_asset",
            [a_sender(sender_wallet, 0_i64, 0_i64)],
            [a_recipient(sender_wallet, 0_i64)],
            [Transaction::Asset.new(asset_id_3, "name3", "description", "media_location3", "media_hash3", 3, "terms", AssetAccess::LOCKED, 2, __timestamp)]
          )

          send_asset_1_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id_1, 1)],
            [an_asset_recipient(sender_wallet, asset_id_1, 1)],
            [] of Transaction::Asset
          )

          send_asset_2_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id_2, 1)],
            [an_asset_recipient(recipient_wallet, asset_id_2, 1)],
            [] of Transaction::Asset
          )

          block_factory.add_slow_block([create_transaction_1, create_transaction_2, create_transaction_3, update_quantity_asset_2, update_quantity_asset_3, send_asset_1_transaction, send_asset_2_transaction]).add_slow_blocks(2)
          component = AssetComponent.new(block_factory.blockchain)

          send_asset_3_transaction = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(sender_wallet, asset_id_3, 4)],
            [an_asset_recipient(recipient_wallet, asset_id_3, 4)],
            [] of Transaction::Asset
          )

          result = component.valid_transactions?([send_asset_3_transaction])
          result.passed.size.should eq(0)
          result.failed.size.should eq(1)
          result.failed.first.reason.should eq("you have 3 quantity of asset: #{asset_id_3} so you cannot send 4")
        end
      end

      it "chain of multiple send assets works correctly (a user can't receive and send the same asset in the same transaction)" do
        with_factory do |block_factory, transaction_factory|
          user_1 = transaction_factory.sender_wallet
          user_2 = transaction_factory.recipient_wallet
          user_3 = Wallet.from_json(Wallet.create(true).to_json)
          user_4 = Wallet.from_json(Wallet.create(true).to_json)

          asset_id = Transaction::Asset.create_id

          create_transaction = transaction_factory.make_asset(
            "AXNT",
            "create_asset",
            [a_sender(user_1, 0_i64, 0_i64)],
            [a_recipient(user_1, 0_i64)],
            [Transaction::Asset.new(asset_id, "name", "description", "media_location", "media_hash", 1, "terms", AssetAccess::LOCKED, 1, __timestamp)]
          )

          send_asset_transaction_1 = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(user_1, asset_id, 1)],
            [an_asset_recipient(user_2, asset_id, 1)],
            [] of Transaction::Asset
          )

          # User 1 create the asset and send to user 2
          block_factory.add_slow_block([create_transaction, send_asset_transaction_1]).add_slow_blocks(2)
          block_factory.database.total_rejects.should eq(0)

          send_asset_transaction_2 = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(user_2, asset_id, 1)],
            [an_asset_recipient(user_3, asset_id, 1)],
            [] of Transaction::Asset,
            user_2
          )

          send_asset_transaction_3 = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(user_3, asset_id, 1)],
            [an_asset_recipient(user_4, asset_id, 1)],
            [] of Transaction::Asset,
            user_3
          )

          # Send asset from user 2 to user 3
          block_factory.add_slow_block([send_asset_transaction_2]).add_slow_blocks(2)
          block_factory.database.total_rejects.should eq(0)

          # Send asset from user 3 to user 4
          block_factory.add_slow_block([send_asset_transaction_3]).add_slow_blocks(2)
          block_factory.database.total_rejects.should eq(0)

          component = AssetComponent.new(block_factory.blockchain)

          send_asset_transaction_4 = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(user_1, asset_id, 1)],
            [an_asset_recipient(user_2, asset_id, 1)],
            [] of Transaction::Asset
          )

          send_asset_transaction_5 = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(user_2, asset_id, 1)],
            [an_asset_recipient(user_3, asset_id, 1)],
            [] of Transaction::Asset
          )

          send_asset_transaction_6 = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(user_3, asset_id, 1)],
            [an_asset_recipient(user_4, asset_id, 1)],
            [] of Transaction::Asset
          )

          send_asset_transaction_7 = transaction_factory.make_asset(
            "AXNT",
            "send_asset",
            [an_asset_sender(user_4, asset_id, 2)],
            [an_asset_recipient(user_1, asset_id, 2)],
            [] of Transaction::Asset
          )

          # user 1,2,3 cannot send as has 0
          # user 4 cannot send 2 as only has 1
          result = component.valid_transactions?([
            send_asset_transaction_4, send_asset_transaction_5, send_asset_transaction_6, send_asset_transaction_7,
          ])
          result.passed.size.should eq(0)
          result.failed.size.should eq(4)
          result.failed.first.reason.should eq("you have 0 quantity of asset: #{asset_id} so you cannot send 1")
          result.failed[1].reason.should eq("you have 0 quantity of asset: #{asset_id} so you cannot send 1")
          result.failed[2].reason.should eq("you have 0 quantity of asset: #{asset_id} so you cannot send 1")
          result.failed[3].reason.should eq("you have 1 quantity of asset: #{asset_id} so you cannot send 2")
        end
      end
    end
  end
end
