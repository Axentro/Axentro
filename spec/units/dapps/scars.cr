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

include Sushi::Core
include Units::Utils
include Sushi::Core::DApps::BuildIn
include Sushi::Core::Controllers

describe Scars do
  describe "#lookup" do
    it "should return an empty array if the address is not mapped to any domains" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_block.chain
        scars = Scars.new(block_factory.blockchain)
        scars.record(chain)
        wallet = Wallet.from_json(Wallet.create(true).to_json)
        scars.lookup_for(wallet.address).should eq [] of Array(Domain)
      end
    end

    it "should return domain info(s) if the address is found" do
      with_factory do |block_factory, transaction_factory|
        domains = ["domain1.sc", "domain2.sc"]
        chain = block_factory.add_slow_blocks(10).add_slow_block(
          [transaction_factory.make_buy_domain_from_platform(domains[0], 0_i64),
          transaction_factory.make_buy_domain_from_platform(domains[1], 0_i64)]).add_slow_blocks(10).chain
        scars = Scars.new(block_factory.blockchain)
        scars.record(chain)

        on_success(scars.lookup_for(transaction_factory.sender_wallet.address)) do |result|
          result.first["domain_name"].should eq(domains[0])
          result[1]["domain_name"].should eq(domains[1])
        end
      end
    end
  end

  describe "#resolve" do
    it "should return nil if the domain is not found" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_block.chain
        scars = Scars.new(block_factory.blockchain)
        scars.record(chain)
        scars.resolve_for("domain1.sc").should be_nil
      end
    end

    it "should return nil if the number internal domains is less than confirmations" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_blocks(10).chain
        scars = Scars.new(block_factory.blockchain)
        scars.record(chain)
        scars.resolve_for("domain1.sc").should be_nil
      end
    end

    it "should return domain info if the domain is found" do
      with_factory do |block_factory, transaction_factory|
        domain = "domain1.sc"
        chain = block_factory.add_slow_blocks(10).add_slow_block([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(10).chain
        scars = Scars.new(block_factory.blockchain)
        scars.record(chain)

        on_success(scars.resolve_for(domain)) do |result|
          result["domain_name"].should eq(domain)
          result["address"].should eq(transaction_factory.sender_wallet.address)
          result["status"].should eq(Status::ACQUIRED)
          result["price"].should eq(0_i64)
        end
      end
    end

    describe "#resolve_pending" do
      it "should return nil if the domain is not found" do
        with_factory do |block_factory, _|
          chain = block_factory.add_slow_block.chain
          scars = Scars.new(block_factory.blockchain)
          scars.record(chain)
          scars.resolve_pending("domain1.sc", chain.last.transactions).should be_nil
        end
      end

      it "should return the domain info for pending domains" do
        with_factory do |block_factory, transaction_factory|
          domain = "domain1.sc"
          transactions = [transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]
          chain = block_factory.add_slow_block(transactions).add_slow_blocks(2).chain
          scars = Scars.new(block_factory.blockchain)
          scars.record(chain)

          on_success(scars.resolve_pending(domain, transactions)) do |result|
            result["domain_name"].should eq(domain)
            result["address"].should eq(transaction_factory.sender_wallet.address)
            result["status"].should eq(Status::ACQUIRED)
            result["price"].should eq(0_i64)
          end
        end
      end
    end

    describe "#transaction_actions" do
      it "should return scars actions" do
        with_factory do |block_factory, _|
          scars = Scars.new(block_factory.blockchain)
          scars.transaction_actions.should eq(["scars_buy", "scars_sell", "scars_cancel"])
        end
      end
    end

    describe "#transaction_related" do
      it "should return true if action is a scars related action" do
        with_factory do |block_factory, _|
          scars = Scars.new(block_factory.blockchain)
          scars.transaction_related?("scars_buy").should be_true
        end
      end
      it "should return false if the action is not a scars related action" do
        with_factory do |block_factory, _|
          scars = Scars.new(block_factory.blockchain)
          scars.transaction_related?("not_related").should be_false
        end
      end
    end

    describe "#valid_buy?" do
      it "should return true when domain is a valid buy from platform" do
        with_factory do |block_factory, transaction_factory|
          tx1 = transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64)
          scars = Scars.new(block_factory.blockchain)
          scars.valid_buy?(tx1, [] of Transaction)
        end
      end

      it "should return true when domain is a valid buy from seller" do
        with_factory do |block_factory, transaction_factory|
          txns = [
            transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64),
            transaction_factory.make_sell_domain("domain1.sc", 500_i64),
          ]

          tx1 = transaction_factory.make_buy_domain_from_seller("domain1.sc", 500_i64)
          scars = Scars.new(block_factory.blockchain)
          scars.valid_buy?(tx1, txns)
        end
      end

      it "should raise error when domain name not for sale" do
        with_factory do |block_factory, transaction_factory|
          txns = [
            transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64),
          ]

          tx1 = transaction_factory.make_buy_domain_from_seller("domain1.sc", 500_i64)
          scars = Scars.new(block_factory.blockchain)
          expect_raises(Exception, "domain domain1.sc is not for sale now") do
            scars.valid_buy?(tx1, txns)
          end
        end
      end

      it "should raise error when trying to buy a domain from seller that has not been bought by anybody yet" do
        with_factory do |block_factory, transaction_factory|
          tx1 = transaction_factory.make_buy_domain_from_seller("domain1.sc", 500_i64)
          scars = Scars.new(block_factory.blockchain)
          expect_raises(Exception, "you cannot set a recipient since nobody has bought the domain: domain1.sc") do
            scars.valid_buy?(tx1, [] of Transaction)
          end
        end
      end

      it "should raise error when trying to buy a domain from seller when not setting the seller's address as the recipient" do
        with_factory do |block_factory, transaction_factory|
          txns = [
            transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64),
            transaction_factory.make_sell_domain("domain1.sc", 500_i64),
          ]

          tx1 = transaction_factory.make_buy_domain_from_seller("domain1.sc", 500_i64, [] of Transaction::Recipient)
          scars = Scars.new(block_factory.blockchain)
          expect_raises(Exception, "you have to the set a domain owner as a recipient") do
            scars.valid_buy?(tx1, txns)
          end
        end
      end

      it "should raise error when trying to buy a domain from seller when setting multiple recipients" do
        with_factory do |block_factory, transaction_factory|
          txns = [
            transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64),
            transaction_factory.make_sell_domain("domain1.sc", 500_i64),
          ]

          recipients = [a_recipient(transaction_factory.sender_wallet, 100_i64), a_recipient(transaction_factory.sender_wallet, 100_i64)]
          tx1 = transaction_factory.make_buy_domain_from_seller("domain1.sc", 500_i64, recipients)
          scars = Scars.new(block_factory.blockchain)
          expect_raises(Exception, "you cannot set multiple recipients") do
            scars.valid_buy?(tx1, txns)
          end
        end
      end

      it "should raise error when trying to buy a domain from seller when setting a recipient which is not the domain owner" do
        with_factory do |block_factory, transaction_factory|
          txns = [
            transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64),
            transaction_factory.make_sell_domain("domain1.sc", 500_i64),
          ]

          recipients = [a_recipient(transaction_factory.recipient_wallet, 100_i64)]
          tx1 = transaction_factory.make_buy_domain_from_seller("domain1.sc", 500_i64, recipients)
          actual = transaction_factory.recipient_wallet.address
          expected = transaction_factory.sender_wallet.address
          scars = Scars.new(block_factory.blockchain)
          expect_raises(Exception, "domain address mismatch: #{actual} vs #{expected}") do
            scars.valid_buy?(tx1, txns)
          end
        end
      end

      it "should raise error when trying to buy a domain from seller when supplying the wrong price" do
        with_factory do |block_factory, transaction_factory|
          txns = [
            transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64),
            transaction_factory.make_sell_domain("domain1.sc", 500_i64),
          ]

          tx1 = transaction_factory.make_buy_domain_from_seller("domain1.sc", 0_i64)
          scars = Scars.new(block_factory.blockchain)
          expect_raises(Exception, "the supplied price 0 is different than the expected price 500") do
            scars.valid_buy?(tx1, txns)
          end
        end
      end
    end

    describe "#valid_sell?" do
      it "should return true on valid sell" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64)]

          tx1 = transaction_factory.make_sell_domain("domain1.sc", 500_i64)
          scars = Scars.new(block_factory.blockchain)
          scars.valid_sell?(tx1, txns).should be_true
        end
      end

      it "should return error when no recipient set" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64)]

          tx1 = transaction_factory.make_sell_domain("domain1.sc", 500_i64, [] of Transaction::Recipient)
          scars = Scars.new(block_factory.blockchain)
          expect_raises(Exception, "you have to set one recipient") do
            scars.valid_sell?(tx1, txns)
          end
        end
      end

      it "should return error when recipient set does not match address of sender" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64)]

          recipients = [a_recipient(transaction_factory.recipient_wallet, 100_i64)]
          tx1 = transaction_factory.make_sell_domain("domain1.sc", 500_i64, recipients)
          actual = transaction_factory.sender_wallet.address
          expected = transaction_factory.recipient_wallet.address
          scars = Scars.new(block_factory.blockchain)
          expect_raises(Exception, "address mismatch for scars_sell: expected #{actual} but got #{expected}") do
            scars.valid_sell?(tx1, txns)
          end
        end
      end

      it "should return error when recipient price does not match sender price" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64)]

          recipients = [a_recipient(transaction_factory.sender_wallet, 200_i64)]
          tx1 = transaction_factory.make_sell_domain("domain1.sc", 500_i64, recipients)
          scars = Scars.new(block_factory.blockchain)

          expect_raises(Exception, "price mismatch for scars_sell: expected 500 but got 200") do
            scars.valid_sell?(tx1, txns)
          end
        end
      end

      it "should return error when domain name not found" do
        with_factory do |block_factory, transaction_factory|
          tx1 = transaction_factory.make_sell_domain("domain1.sc", 500_i64)
          scars = Scars.new(block_factory.blockchain)

          expect_raises(Exception, "domain domain1.sc not found") do
            scars.valid_sell?(tx1, [] of Transaction)
          end
        end
      end

      it "should return error when setting the wrong address for the domain owner" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64)]
          recipients = [a_recipient(transaction_factory.sender_wallet, 100_i64)]

          tx1 = transaction_factory.make_sell_domain("domain1.sc", 100_i64, recipients, transaction_factory.recipient_wallet)
          actual = transaction_factory.recipient_wallet.address
          expected = transaction_factory.sender_wallet.address
          scars = Scars.new(block_factory.blockchain)
          expect_raises(Exception, "domain address mismatch: expected #{actual} but got #{expected}") do
            scars.valid_sell?(tx1, txns)
          end
        end
      end

      it "should return error when selling price is not greater than 0" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64)]
          tx1 = transaction_factory.make_sell_domain("domain1.sc", -1_i64)
          scars = Scars.new(block_factory.blockchain)

          expect_raises(Exception, "the selling price must be 0 or higher") do
            scars.valid_sell?(tx1, txns)
          end
        end
      end
    end

    describe "#valid_cancel" do
      it "should return true on valid cancel" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64),
                  transaction_factory.make_sell_domain("domain1.sc", 500_i64)]

          tx1 = transaction_factory.make_cancel_domain("domain1.sc", 500_i64)
          scars = Scars.new(block_factory.blockchain)
          scars.valid_cancel?(tx1, txns).should be_true
        end
      end

      it "should return error when no recipient set" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64),
                  transaction_factory.make_sell_domain("domain1.sc", 500_i64)]

          tx1 = transaction_factory.make_cancel_domain("domain1.sc", 500_i64, [] of Transaction::Recipient)
          scars = Scars.new(block_factory.blockchain)
          expect_raises(Exception, "you have to set one recipient") do
            scars.valid_cancel?(tx1, txns)
          end
        end
      end

      it "should return error when recipient set does not match address of sender" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64),
                  transaction_factory.make_sell_domain("domain1.sc", 500_i64)]

          recipients = [a_recipient(transaction_factory.recipient_wallet, 100_i64)]
          tx1 = transaction_factory.make_cancel_domain("domain1.sc", 500_i64, recipients)
          actual = transaction_factory.sender_wallet.address
          expected = transaction_factory.recipient_wallet.address
          scars = Scars.new(block_factory.blockchain)
          expect_raises(Exception, "address mismatch for scars_cancel: expected #{actual} but got #{expected}") do
            scars.valid_cancel?(tx1, txns)
          end
        end
      end

      it "should return error when recipient price does not match sender price" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64),
                  transaction_factory.make_sell_domain("domain1.sc", 500_i64)]

          recipients = [a_recipient(transaction_factory.sender_wallet, 200_i64)]
          tx1 = transaction_factory.make_cancel_domain("domain1.sc", 500_i64, recipients)
          scars = Scars.new(block_factory.blockchain)

          expect_raises(Exception, "price mismatch for scars_cancel: expected 500 but got 200") do
            scars.valid_cancel?(tx1, txns)
          end
        end
      end

      it "should return error when domain name not found" do
        with_factory do |block_factory, transaction_factory|
          tx1 = transaction_factory.make_cancel_domain("domain1.sc", 500_i64)
          scars = Scars.new(block_factory.blockchain)

          expect_raises(Exception, "domain domain1.sc not found") do
            scars.valid_cancel?(tx1, [] of Transaction)
          end
        end
      end

      it "should return error when setting the wrong address for the domain owner" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64),
                  transaction_factory.make_sell_domain("domain1.sc", 500_i64)]
          recipients = [a_recipient(transaction_factory.sender_wallet, 100_i64)]

          tx1 = transaction_factory.make_cancel_domain("domain1.sc", 100_i64, recipients, transaction_factory.recipient_wallet)
          actual = transaction_factory.recipient_wallet.address
          expected = transaction_factory.sender_wallet.address
          scars = Scars.new(block_factory.blockchain)
          expect_raises(Exception, "domain address mismatch: expected #{actual} but got #{expected}") do
            scars.valid_cancel?(tx1, txns)
          end
        end
      end
    end

    describe "#define_rpc" do
      describe "#scars_resolve" do
        it "should return the resolved address for the domain when 1 confirmation" do
          with_factory do |block_factory, transaction_factory|
            domain = "awesome.sc"
            block_factory.add_slow_blocks(10).add_slow_block([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(10)

            payload = {call: "scars_resolve", domain_name: domain, confirmation: 1}.to_json
            json = JSON.parse(payload)

            with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
              result.should eq("{\"resolved\":true,\"confirmation\":1,\"domain\":{\"domain_name\":\"awesome.sc\",\"address\":\"#{transaction_factory.sender_wallet.address}\",\"status\":0,\"price\":\"0\"}}")
            end
          end
        end

        it "should not resolve the address if the domain does not exist" do
          with_factory do |block_factory, _|
            domain = "awesome.sc"
            block_factory.add_slow_block

            payload = {call: "scars_resolve", domain_name: domain, confirmation: 1}.to_json
            json = JSON.parse(payload)

            with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
              result.should eq("{\"resolved\":false,\"confirmation\":1,\"domain\":{\"domain_name\":\"awesome.sc\",\"address\":\"\",\"status\":-1,\"price\":\"0.0\"}}")
            end
          end
        end
      end

      describe "#scars_sales" do
        it "should list domains for sale" do
          with_factory do |block_factory, transaction_factory|
            domain = "awesome.sc"
            block_factory.add_slow_blocks(10).add_slow_block([
              transaction_factory.make_buy_domain_from_platform(domain, 0_i64),
              transaction_factory.make_sell_domain(domain, 20000000_i64),
            ]).add_slow_block

            payload = {call: "scars_for_sale"}.to_json
            json = JSON.parse(payload)

            with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
              result.should eq("[{\"domain_name\":\"awesome.sc\",\"address\":\"#{transaction_factory.sender_wallet.address}\",\"status\":1,\"price\":\"0.2\"}]")
            end
          end
        end
      end
    end

    describe "#valid_transaction?" do
      it "should return true when domain is a valid buy from platform" do
        with_factory do |block_factory, transaction_factory|
          tx1 = transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64)
          scars = Scars.new(block_factory.blockchain)
          scars.valid_transaction?(tx1, [] of Transaction)
        end
      end
      it "should return true on valid sell" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64)]

          tx1 = transaction_factory.make_sell_domain("domain1.sc", 500_i64)
          scars = Scars.new(block_factory.blockchain)
          scars.valid_transaction?(tx1, txns).should be_true
        end
      end
      it "should return false when neither buy or sell" do
        with_factory do |block_factory, transaction_factory|
          tx1 = transaction_factory.make_send(100_i64)
          scars = Scars.new(block_factory.blockchain)
          scars.valid_transaction?(tx1, [] of Transaction).should be_false
        end
      end
    end

    describe "#valid_domain?" do
      it "should return true when domain name is valid" do
        with_factory do |block_factory, _|
          scars = Scars.new(block_factory.blockchain)
          scars.valid_domain?("sushi.sc").should be_true
        end
      end

      it "should raise an error with a message when " do
        with_factory do |block_factory, _|
          domain_rule = <<-RULE
          Your domain '123456789012345678901.sc' is not valid

          1. domain name can only contain only alphanumerics
          2. domain name must end with one of these suffixes: ["sc"]
          3. domain name length must be between 1 and 20 characters (excluding suffix
          RULE

          scars = Scars.new(block_factory.blockchain)
          expect_raises(Exception, domain_rule) do
            scars.valid_domain?("123456789012345678901.sc")
          end
        end
      end

      it "should raise an error when domain name is longer than 20 characters" do
        with_factory do |block_factory, _|
          scars = Scars.new(block_factory.blockchain)
          expect_raises(Exception) do
            scars.valid_domain?("123456789012345678901.sc")
          end
        end
      end

      it "should raise an error when domain name does not contain a dot" do
        with_factory do |block_factory, _|
          scars = Scars.new(block_factory.blockchain)
          expect_raises(Exception) do
            scars.valid_domain?("nodotsc")
          end
        end
      end

      it "should raise an error when domain name does not end with .sc prefix" do
        with_factory do |block_factory, _|
          scars = Scars.new(block_factory.blockchain)
          expect_raises(Exception) do
            scars.valid_domain?("domain.rt")
          end
        end
      end

      it "should raise an error when domain name contains empty spaces" do
        with_factory do |block_factory, _|
          scars = Scars.new(block_factory.blockchain)
          expect_raises(Exception) do
            scars.valid_domain?("h e l l o.sc")
          end
        end
      end

      it "should work when using Self.valid_domain?" do
        Scars.valid_domain?("domain.sc").should be_true
      end
    end

    describe "#Scars.fee" do
      it "should show the fee for an action" do
        Scars.fee("scars_buy").should eq(100000_i64)
        Scars.fee("scars_sell").should eq(10000_i64)
        Scars.fee("scars_cancel").should eq(10000_i64)
      end

      it "should raise an error if fee type is unknown" do
        expect_raises(Exception, "got unknown action unknown while getting a fee for scars") do
          Scars.fee("unknown").should eq(0_i64)
        end
      end
    end

    describe "#scars_for_sale_impl" do
      it "should list all the domains that are for sale" do
        with_factory do |block_factory, transaction_factory|
          domain = "domain1.sc"
          txns = [
            transaction_factory.make_buy_domain_from_platform(domain, 0_i64),
            transaction_factory.make_sell_domain(domain, 500_i64),
          ]
          chain = block_factory.add_slow_block(txns).add_slow_blocks(10).chain
          scars = Scars.new(block_factory.blockchain)
          scars.record(chain)

          sales = scars.scars_for_sale_impl
          sales.size.should eq(1)

          result = sales.first
          result["domain_name"].should eq(domain)
          result["address"].should eq(transaction_factory.sender_wallet.address)
          result["status"].should eq(Status::FOR_SALE)
          result["price"].should eq("0.000005")
        end
      end

      it "should return empty list when no domains are for sale" do
        with_factory do |block_factory, _|
          scars = Scars.new(block_factory.blockchain)
          scars.scars_for_sale_impl.size.should eq(0)
        end
      end
    end
  end
end

def on_success(result, &block)
  if result.nil?
    fail("value should not be nil")
  else
    yield result
  end
end
