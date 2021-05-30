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

describe Hra do
  describe "#lookup" do
    it "should return an empty array if the address is not mapped to any domains" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_block.chain
        hra = Hra.new(block_factory.blockchain)
        hra.record(chain)
        wallet = Wallet.from_json(Wallet.create(true).to_json)
        hra.lookup_for(wallet.address).should eq [] of Array(Domain)
      end
    end

    it "should return domain info(s) if the address is found" do
      with_factory do |block_factory, transaction_factory|
        domains = ["domain1.ax", "domain2.ax"]
        chain = block_factory.add_slow_blocks(10).add_slow_block(
          [transaction_factory.make_buy_domain_from_platform(domains[0], 0_i64)]).add_slow_blocks(10).chain
        hra = Hra.new(block_factory.blockchain)
        hra.record(chain)

        on_success(hra.lookup_for(transaction_factory.sender_wallet.address)) do |result|
          result.first["domain_name"].should eq(domains[0])
        end
      end
    end
  end

  describe "#resolve" do
    it "should return nil if the domain is not found" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_block.chain
        hra = Hra.new(block_factory.blockchain)
        hra.record(chain)
        hra.resolve_for("domain1.ax").should be_nil
      end
    end

    it "should return nil if the number internal domains is less than confirmations" do
      with_factory do |block_factory, _|
        chain = block_factory.add_slow_blocks(10).chain
        hra = Hra.new(block_factory.blockchain)
        hra.record(chain)
        hra.resolve_for("domain1.ax").should be_nil
      end
    end

    it "should return domain info if the domain is found" do
      with_factory do |block_factory, transaction_factory|
        domain = "domain1.ax"
        chain = block_factory.add_slow_blocks(10).add_slow_block([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(10).chain
        hra = Hra.new(block_factory.blockchain)
        hra.record(chain)

        on_success(hra.resolve_for(domain)) do |result|
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
          hra = Hra.new(block_factory.blockchain)
          hra.record(chain)
          hra.resolve_pending("domain1.ax", chain.last.transactions).should be_nil
        end
      end

      it "should return the domain info for pending domains" do
        with_factory do |block_factory, transaction_factory|
          domain = "domain1.ax"
          transactions = [transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]
          chain = block_factory.add_slow_block(transactions).add_slow_blocks(2).chain
          hra = Hra.new(block_factory.blockchain)
          hra.record(chain)

          on_success(hra.resolve_pending(domain, transactions)) do |result|
            result["domain_name"].should eq(domain)
            result["address"].should eq(transaction_factory.sender_wallet.address)
            result["status"].should eq(Status::ACQUIRED)
            result["price"].should eq(0_i64)
          end
        end
      end
    end

    describe "#transaction_actions" do
      it "should return hra actions" do
        with_factory do |block_factory, _|
          hra = Hra.new(block_factory.blockchain)
          hra.transaction_actions.should eq(["hra_buy", "hra_sell", "hra_cancel"])
        end
      end
    end

    describe "#transaction_related" do
      it "should return true if action is a hra related action" do
        with_factory do |block_factory, _|
          hra = Hra.new(block_factory.blockchain)
          hra.transaction_related?("hra_buy").should be_true
        end
      end
      it "should return false if the action is not a hra related action" do
        with_factory do |block_factory, _|
          hra = Hra.new(block_factory.blockchain)
          hra.transaction_related?("not_related").should be_false
        end
      end
    end

    describe "#valid_buy?" do
      it "should return true when domain is a valid buy from platform" do
        with_factory do |block_factory, transaction_factory|
          tx1 = transaction_factory.make_buy_domain_from_platform("domain1.ax", 0_i64)
          hra = Hra.new(block_factory.blockchain)
          hra.valid_buy?(tx1, [] of Transaction)
        end
      end

      it "should return true when domain is a valid buy from seller" do
        with_factory do |block_factory, transaction_factory|
          txns = [
            transaction_factory.make_buy_domain_from_platform("domain1.ax", 0_i64),
            transaction_factory.make_sell_domain("domain1.ax", 500_i64),
          ]

          tx1 = transaction_factory.make_buy_domain_from_seller("domain1.ax", 500_i64)
          hra = Hra.new(block_factory.blockchain)
          hra.valid_buy?(tx1, txns)
        end
      end

      it "should raise error when trying to buy more than one domain for an address" do
        with_factory do |block_factory, transaction_factory|
          txns = [
            transaction_factory.make_buy_domain_from_platform("domain1.ax", 0_i64),
          ]

          chain = block_factory.add_slow_block(txns).add_slow_blocks(2).chain
          hra = Hra.new(block_factory.blockchain)
          hra.record(chain)

          tx1 = transaction_factory.make_buy_domain_from_platform("domain2.ax", 0_i64)
          expect_raises(Exception, "You may only have 1 human readable address per wallet address. You already own: domain1.ax") do
            hra.valid_buy?(tx1, txns)
          end
        end
      end

      it "should raise error when domain name not for sale" do
        with_factory do |block_factory, transaction_factory|
          txns = [
            transaction_factory.make_buy_domain_from_platform("domain1.ax", 0_i64),
          ]

          tx1 = transaction_factory.make_buy_domain_from_seller("domain1.ax", 500_i64)
          hra = Hra.new(block_factory.blockchain)
          expect_raises(Exception, "domain domain1.ax is not for sale now") do
            hra.valid_buy?(tx1, txns)
          end
        end
      end

      it "should raise error when trying to buy a domain from seller that has not been bought by anybody yet" do
        with_factory do |block_factory, transaction_factory|
          tx1 = transaction_factory.make_buy_domain_from_seller("domain1.ax", 500_i64)
          hra = Hra.new(block_factory.blockchain)
          expect_raises(Exception, "you cannot set a recipient since nobody has bought the domain: domain1.ax") do
            hra.valid_buy?(tx1, [] of Transaction)
          end
        end
      end

      it "should raise error when trying to buy a domain from seller when not setting the seller's address as the recipient" do
        with_factory do |block_factory, transaction_factory|
          txns = [
            transaction_factory.make_buy_domain_from_platform("domain1.ax", 0_i64),
            transaction_factory.make_sell_domain("domain1.ax", 500_i64),
          ]

          tx1 = transaction_factory.make_buy_domain_from_seller("domain1.ax", 500_i64, [] of Transaction::Recipient)
          hra = Hra.new(block_factory.blockchain)
          expect_raises(Exception, "you have to the set a domain owner as a recipient") do
            hra.valid_buy?(tx1, txns)
          end
        end
      end

      it "should raise error when trying to buy a domain from seller when setting multiple recipients" do
        with_factory do |block_factory, transaction_factory|
          txns = [
            transaction_factory.make_buy_domain_from_platform("domain1.ax", 0_i64),
            transaction_factory.make_sell_domain("domain1.ax", 500_i64),
          ]

          recipients = [a_recipient(transaction_factory.sender_wallet, 100_i64), a_recipient(transaction_factory.sender_wallet, 100_i64)]
          tx1 = transaction_factory.make_buy_domain_from_seller("domain1.ax", 500_i64, recipients)
          hra = Hra.new(block_factory.blockchain)
          expect_raises(Exception, "you cannot set multiple recipients") do
            hra.valid_buy?(tx1, txns)
          end
        end
      end

      it "should raise error when trying to buy a domain from seller when setting a recipient which is not the domain owner" do
        with_factory do |block_factory, transaction_factory|
          txns = [
            transaction_factory.make_buy_domain_from_platform("domain1.ax", 0_i64),
            transaction_factory.make_sell_domain("domain1.ax", 500_i64),
          ]

          recipients = [a_recipient(transaction_factory.recipient_wallet, 100_i64)]
          tx1 = transaction_factory.make_buy_domain_from_seller("domain1.ax", 500_i64, recipients)
          actual = transaction_factory.recipient_wallet.address
          expected = transaction_factory.sender_wallet.address
          hra = Hra.new(block_factory.blockchain)
          expect_raises(Exception, "domain address mismatch: #{actual} vs #{expected}") do
            hra.valid_buy?(tx1, txns)
          end
        end
      end

      it "should raise error when trying to buy a domain from seller when supplying the wrong price" do
        with_factory do |block_factory, transaction_factory|
          txns = [
            transaction_factory.make_buy_domain_from_platform("domain1.ax", 0_i64),
            transaction_factory.make_sell_domain("domain1.ax", 500_i64),
          ]

          tx1 = transaction_factory.make_buy_domain_from_seller("domain1.ax", 0_i64)
          hra = Hra.new(block_factory.blockchain)
          expect_raises(Exception, "the supplied price 0 is different than the expected price 500") do
            hra.valid_buy?(tx1, txns)
          end
        end
      end
    end

    describe "#valid_sell?" do
      it "should return true on valid sell" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.ax", 0_i64)]

          tx1 = transaction_factory.make_sell_domain("domain1.ax", 500_i64)
          hra = Hra.new(block_factory.blockchain)
          hra.valid_sell?(tx1, txns).should be_true
        end
      end

      it "should return error when no recipient set" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.ax", 0_i64)]

          tx1 = transaction_factory.make_sell_domain("domain1.ax", 500_i64, [] of Transaction::Recipient)
          hra = Hra.new(block_factory.blockchain)
          expect_raises(Exception, "you have to set one recipient") do
            hra.valid_sell?(tx1, txns)
          end
        end
      end

      it "should return error when recipient set does not match address of sender" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.ax", 0_i64)]

          recipients = [a_recipient(transaction_factory.recipient_wallet, 100_i64)]
          tx1 = transaction_factory.make_sell_domain("domain1.ax", 500_i64, recipients)
          actual = transaction_factory.sender_wallet.address
          expected = transaction_factory.recipient_wallet.address
          hra = Hra.new(block_factory.blockchain)
          expect_raises(Exception, "address mismatch for hra_sell: expected #{actual} but got #{expected}") do
            hra.valid_sell?(tx1, txns)
          end
        end
      end

      it "should return error when recipient price does not match sender price" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.ax", 0_i64)]

          recipients = [a_recipient(transaction_factory.sender_wallet, 200_i64)]
          tx1 = transaction_factory.make_sell_domain("domain1.ax", 500_i64, recipients)
          hra = Hra.new(block_factory.blockchain)

          expect_raises(Exception, "price mismatch for hra_sell: expected 500 but got 200") do
            hra.valid_sell?(tx1, txns)
          end
        end
      end

      it "should return error when domain name not found" do
        with_factory do |block_factory, transaction_factory|
          tx1 = transaction_factory.make_sell_domain("domain1.ax", 500_i64)
          hra = Hra.new(block_factory.blockchain)

          expect_raises(Exception, "domain domain1.ax not found") do
            hra.valid_sell?(tx1, [] of Transaction)
          end
        end
      end

      it "should return error when setting the wrong address for the domain owner" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.ax", 0_i64)]
          recipients = [a_recipient(transaction_factory.sender_wallet, 100_i64)]

          tx1 = transaction_factory.make_sell_domain("domain1.ax", 100_i64, recipients, transaction_factory.recipient_wallet)
          actual = transaction_factory.recipient_wallet.address
          expected = transaction_factory.sender_wallet.address
          hra = Hra.new(block_factory.blockchain)
          expect_raises(Exception, "domain address mismatch: expected #{actual} but got #{expected}") do
            hra.valid_sell?(tx1, txns)
          end
        end
      end

      it "should return error when selling price is not greater than 0" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.ax", 0_i64)]
          tx1 = transaction_factory.make_sell_domain("domain1.ax", -1_i64)
          hra = Hra.new(block_factory.blockchain)

          expect_raises(Exception, "the selling price must be 0 or higher") do
            hra.valid_sell?(tx1, txns)
          end
        end
      end
    end

    describe "#valid_cancel" do
      it "should return true on valid cancel" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.ax", 0_i64),
                  transaction_factory.make_sell_domain("domain1.ax", 500_i64)]

          tx1 = transaction_factory.make_cancel_domain("domain1.ax", 500_i64)
          hra = Hra.new(block_factory.blockchain)
          hra.valid_cancel?(tx1, txns).should be_true
        end
      end

      it "should return error when no recipient set" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.ax", 0_i64),
                  transaction_factory.make_sell_domain("domain1.ax", 500_i64)]

          tx1 = transaction_factory.make_cancel_domain("domain1.ax", 500_i64, [] of Transaction::Recipient)
          hra = Hra.new(block_factory.blockchain)
          expect_raises(Exception, "you have to set one recipient") do
            hra.valid_cancel?(tx1, txns)
          end
        end
      end

      it "should return error when recipient set does not match address of sender" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.ax", 0_i64),
                  transaction_factory.make_sell_domain("domain1.ax", 500_i64)]

          recipients = [a_recipient(transaction_factory.recipient_wallet, 100_i64)]
          tx1 = transaction_factory.make_cancel_domain("domain1.ax", 500_i64, recipients)
          actual = transaction_factory.sender_wallet.address
          expected = transaction_factory.recipient_wallet.address
          hra = Hra.new(block_factory.blockchain)
          expect_raises(Exception, "address mismatch for hra_cancel: expected #{actual} but got #{expected}") do
            hra.valid_cancel?(tx1, txns)
          end
        end
      end

      it "should return error when recipient price does not match sender price" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.ax", 0_i64),
                  transaction_factory.make_sell_domain("domain1.ax", 500_i64)]

          recipients = [a_recipient(transaction_factory.sender_wallet, 200_i64)]
          tx1 = transaction_factory.make_cancel_domain("domain1.ax", 500_i64, recipients)
          hra = Hra.new(block_factory.blockchain)

          expect_raises(Exception, "price mismatch for hra_cancel: expected 500 but got 200") do
            hra.valid_cancel?(tx1, txns)
          end
        end
      end

      it "should return error when domain name not found" do
        with_factory do |block_factory, transaction_factory|
          tx1 = transaction_factory.make_cancel_domain("domain1.ax", 500_i64)
          hra = Hra.new(block_factory.blockchain)

          expect_raises(Exception, "domain domain1.ax not found") do
            hra.valid_cancel?(tx1, [] of Transaction)
          end
        end
      end

      it "should return error when setting the wrong address for the domain owner" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.ax", 0_i64),
                  transaction_factory.make_sell_domain("domain1.ax", 500_i64)]
          recipients = [a_recipient(transaction_factory.sender_wallet, 100_i64)]

          tx1 = transaction_factory.make_cancel_domain("domain1.ax", 100_i64, recipients, transaction_factory.recipient_wallet)
          actual = transaction_factory.recipient_wallet.address
          expected = transaction_factory.sender_wallet.address
          hra = Hra.new(block_factory.blockchain)
          expect_raises(Exception, "domain address mismatch: expected #{actual} but got #{expected}") do
            hra.valid_cancel?(tx1, txns)
          end
        end
      end
    end

    describe "#define_rpc" do
      describe "#hra_resolve" do
        it "should return the resolved address for the domain when 1 confirmation" do
          with_factory do |block_factory, transaction_factory|
            domain = "awesome.ax"
            block_factory.add_slow_blocks(10).add_slow_block([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).add_slow_blocks(10)

            payload = {call: "hra_resolve", domain_name: domain, confirmation: 0}.to_json
            json = JSON.parse(payload)

            with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
              result.should eq("{\"resolved\":true,\"confirmation\":10,\"domain\":{\"domain_name\":\"awesome.ax\",\"address\":\"#{transaction_factory.sender_wallet.address}\",\"status\":\"acquired\",\"price\":\"0\",\"block\":22}}")
            end
          end
        end

        it "should not resolve the address if the domain does not exist" do
          with_factory do |block_factory, _|
            domain = "awesome.ax"
            block_factory.add_slow_block

            payload = {call: "hra_resolve", domain_name: domain, confirmation: 1}.to_json
            json = JSON.parse(payload)

            with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
              result.should eq("{\"resolved\":false,\"confirmation\":0,\"domain\":{\"domain_name\":\"awesome.ax\",\"address\":\"\",\"status\":\"not_found\",\"price\":\"0.0\"}}")
            end
          end
        end
      end

      describe "#hra_sales" do
        it "should list domains for sale" do
          with_factory do |block_factory, transaction_factory|
            domain = "awesome.ax"
            block_factory.add_slow_blocks(10).add_slow_block([
              transaction_factory.make_buy_domain_from_platform(domain, 0_i64),
              transaction_factory.make_sell_domain(domain, 20000000_i64),
            ]).add_slow_block

            payload = {call: "hra_for_sale"}.to_json
            json = JSON.parse(payload)

            with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
              result.should eq("[{\"domain_name\":\"awesome.ax\",\"address\":\"#{transaction_factory.sender_wallet.address}\",\"status\":\"for_sale\",\"price\":\"0.2\",\"block\":22}]")
            end
          end
        end
      end
    end

    describe "#valid_transactions?" do
      it "should return pass when domain is a valid buy from platform" do
        with_factory do |block_factory, transaction_factory|
          tx1 = transaction_factory.make_buy_domain_from_platform("domain1.ax", 0_i64)
          hra = Hra.new(block_factory.blockchain)
          result = hra.valid_transactions?([tx1])
          result.passed.size.should eq(1)
          result.failed.size.should eq(0)
          result.passed.first.should eq(tx1)
        end
      end
      it "should return pass on valid sell" do
        with_factory do |block_factory, transaction_factory|
          txns = [
            transaction_factory.make_buy_domain_from_platform("domain1.ax", 0_i64),
            transaction_factory.make_sell_domain("domain1.ax", 500_i64),
          ]

          hra = Hra.new(block_factory.blockchain)
          result = hra.valid_transactions?(txns)
          result.passed.size.should eq(2)
          result.failed.size.should eq(0)
          result.passed.should eq(txns)
        end
      end
    end

    describe "#valid_domain?" do
      it "should return true when domain name is valid" do
        with_factory do |block_factory, _|
          hra = Hra.new(block_factory.blockchain)
          hra.valid_domain?("axentro.ax").should be_true
        end
      end

      it "should raise an error with a message when " do
        with_factory do |block_factory, _|
          domain_rule = <<-RULE
          Your domain '123456789012345678901.ax' is not valid

          1. domain name can only contain only alphanumerics
          2. domain name must end with one of these suffixes: ["ax"]
          3. domain name length must be between 1 and 20 characters (excluding suffix
          RULE

          hra = Hra.new(block_factory.blockchain)
          expect_raises(Exception, domain_rule) do
            hra.valid_domain?("123456789012345678901.ax")
          end
        end
      end

      it "should raise an error when domain name is longer than 20 characters" do
        with_factory do |block_factory, _|
          hra = Hra.new(block_factory.blockchain)
          expect_raises(Exception) do
            hra.valid_domain?("123456789012345678901.ax")
          end
        end
      end

      it "should raise an error when domain name does not contain a dot" do
        with_factory do |block_factory, _|
          hra = Hra.new(block_factory.blockchain)
          expect_raises(Exception) do
            hra.valid_domain?("nodotsc")
          end
        end
      end

      it "should raise an error when domain name does not end with .ax prefix" do
        with_factory do |block_factory, _|
          hra = Hra.new(block_factory.blockchain)
          expect_raises(Exception) do
            hra.valid_domain?("domain.rt")
          end
        end
      end

      it "should raise an error when domain name contains empty spaces" do
        with_factory do |block_factory, _|
          hra = Hra.new(block_factory.blockchain)
          expect_raises(Exception) do
            hra.valid_domain?("h e l l o.ax")
          end
        end
      end

      it "should work when using Self.valid_domain?" do
        Hra.valid_domain?("domain.ax").should be_true
      end
    end

    describe "#Hra.fee" do
      it "should show the fee for an action" do
        Hra.fee("hra_buy").should eq(100000_i64)
        Hra.fee("hra_sell").should eq(10000_i64)
        Hra.fee("hra_cancel").should eq(10000_i64)
      end

      it "should raise an error if fee type is unknown" do
        expect_raises(Exception, "got unknown action unknown while getting a fee for hra") do
          Hra.fee("unknown").should eq(0_i64)
        end
      end
    end

    describe "#hra_for_sale_impl" do
      it "should list all the domains that are for sale" do
        with_factory do |block_factory, transaction_factory|
          domain = "domain1.ax"
          txns = [
            transaction_factory.make_buy_domain_from_platform(domain, 0_i64),
            transaction_factory.make_sell_domain(domain, 500_i64),
          ]
          chain = block_factory.add_slow_block(txns).add_slow_blocks(10).chain
          hra = Hra.new(block_factory.blockchain)
          hra.record(chain)

          sales = hra.hra_for_sale_impl
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
          hra = Hra.new(block_factory.blockchain)
          hra.hra_for_sale_impl.size.should eq(0)
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
