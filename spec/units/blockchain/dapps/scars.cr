require "./../../../spec_helper.cr"
require "./../../utils"

include Sushi::Core::Models
include Sushi::Core
include Units::Utils
include Sushi::Core::DApps::BuildIn

describe Scars do
  describe "#resolve" do
    it "should return nil if the domain is not found" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlock.chain
        scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
        scars.record(chain)
        scars.resolve("domain1.sc").should be_nil
      end
    end

    it "should return nil if the number internal domains is less than confirmations" do
      with_factory do |block_factory, transaction_factory|
        chain = block_factory.addBlocks(10).chain
        scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
        scars.record(chain)
        scars.resolve("domain1.sc").should be_nil
      end
    end

    it "should return domain info if the domain is found" do
      with_factory do |block_factory, transaction_factory|
        domain = "domain1.sc"
        chain = block_factory.addBlock([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).addBlocks(10).chain
        scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
        scars.record(chain)

        onSuccess(scars.resolve(domain)) do |result|
          result["domain_name"].should eq(domain)
          result["address"].should eq(transaction_factory.sender_wallet.address)
          result["status"].should eq(0)
          result["price"].should eq(0_i64)
        end
      end
    end

    describe "#resolve_unconfirmed" do
      it "should return nil if the domain is not found" do
        with_factory do |block_factory, transaction_factory|
          chain = block_factory.addBlock.chain
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          scars.record(chain)
          scars.resolve_unconfirmed("domain1.sc", chain.last.transactions).should be_nil
        end
      end

      it "should return the domain info for unconfirmed domains" do
        with_factory do |block_factory, transaction_factory|
          domain = "domain1.sc"
          transactions = [transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]
          chain = block_factory.addBlock(transactions).addBlocks(2).chain
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          scars.record(chain)

          onSuccess(scars.resolve_unconfirmed(domain, transactions)) do |result|
            result["domain_name"].should eq(domain)
            result["address"].should eq(transaction_factory.sender_wallet.address)
            result["status"].should eq(0)
            result["price"].should eq(0_i64)
          end
        end
      end
    end

    describe "#transaction_actions" do
      it "should return scars actions" do
        with_factory do |block_factory, transaction_factory|
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          scars.transaction_actions.should eq(["scars_buy", "scars_sell", "scars_cancel"])
        end
      end
    end

    describe "#transaction_related" do
      it "should return true if action is a scars related action" do
        with_factory do |block_factory, transaction_factory|
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          scars.transaction_related?("scars_buy").should be_true
        end
      end
      it "should return false if the action is not a scars related action" do
        with_factory do |block_factory, transaction_factory|
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          scars.transaction_related?("not_related").should be_false
        end
      end
    end

    describe "#valid_buy?" do
      it "should return true when domain is a valid buy from platform" do
        with_factory do |block_factory, transaction_factory|
          tx1 = transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64)
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
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
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          scars.valid_buy?(tx1, txns)
        end
      end

      it "should raise error when domain name not for sale" do
        with_factory do |block_factory, transaction_factory|
          txns = [
            transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64),
          ]

          tx1 = transaction_factory.make_buy_domain_from_seller("domain1.sc", 500_i64)
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          expect_raises(Exception, "domain domain1.sc is not for sale now") do
            scars.valid_buy?(tx1, txns)
          end
        end
      end

      it "should raise error when trying to buy a domain from seller that has not been bought by anybody yet" do
        with_factory do |block_factory, transaction_factory|
          tx1 = transaction_factory.make_buy_domain_from_seller("domain1.sc", 500_i64)
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          expect_raises(Exception, "you cannot set a recipient since no body has bought the domain: domain1.sc") do
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

          tx1 = transaction_factory.make_buy_domain_from_seller("domain1.sc", 500_i64, [] of Recipient)
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
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
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
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
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
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
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          expect_raises(Exception, "the supplied price 0 is different to expected price 500") do
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
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          scars.valid_sell?(tx1, txns).should be_true
        end
      end

      it "should return error when no recipient set" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64)]

          tx1 = transaction_factory.make_sell_domain("domain1.sc", 500_i64, [] of Recipient)
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
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
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
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
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))

          expect_raises(Exception, "price mismatch for scars_sell: expected 500 but got 200") do
            scars.valid_sell?(tx1, txns)
          end
        end
      end

      it "should return error when domain name not found" do
        with_factory do |block_factory, transaction_factory|
          tx1 = transaction_factory.make_sell_domain("domain1.sc", 500_i64)
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))

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
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          expect_raises(Exception, "domain address mismatch: expected #{actual} but got #{expected}") do
            scars.valid_sell?(tx1, txns)
          end
        end
      end

      it "should return error when selling price is not greater than 0" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64)]
          tx1 = transaction_factory.make_sell_domain("domain1.sc", -1_i64)
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))

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
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          scars.valid_cancel?(tx1, txns).should be_true
        end
      end

      it "should return error when no recipient set" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64),
                  transaction_factory.make_sell_domain("domain1.sc", 500_i64)]

          tx1 = transaction_factory.make_cancel_domain("domain1.sc", 500_i64, [] of Recipient)
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
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
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          expect_raises(Exception, "address mismatch for scars_sell: expected #{actual} but got #{expected}") do
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
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))

          expect_raises(Exception, "price mismatch for scars_sell: expected 500 but got 200") do
            scars.valid_cancel?(tx1, txns)
          end
        end
      end

      it "should return error when domain name not found" do
        with_factory do |block_factory, transaction_factory|
          tx1 = transaction_factory.make_cancel_domain("domain1.sc", 500_i64)
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))

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
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          expect_raises(Exception, "domain address mismatch: expected #{actual} but got #{expected}") do
            scars.valid_cancel?(tx1, txns)
          end
        end
      end
    end

    describe "#define_rpc" do
      pending "should handle scars_resolve" do
        with_factory do |block_factory, transaction_factory|
          json = {domain_name: "domain.sc", confirmed: true}.to_json
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          # a = scars.define_rpc?("scars_resolve", json, MockContext.new(""), nil)
          # p a
        end
      end
    end

    describe "#valid_transaction?" do
      it "should return true when domain is a valid buy from platform" do
        with_factory do |block_factory, transaction_factory|
          tx1 = transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64)
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          scars.valid_transaction?(tx1, [] of Transaction)
        end
      end
      it "should return true on valid sell" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64)]

          tx1 = transaction_factory.make_sell_domain("domain1.sc", 500_i64)
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          scars.valid_transaction?(tx1, txns).should be_true
        end
      end
      it "should return false when neither buy or sell" do
        with_factory do |block_factory, transaction_factory|
          tx1 = transaction_factory.make_send(100_i64)
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          scars.valid_transaction?(tx1, [] of Transaction).should be_false
        end
      end
    end

    describe "#valid_domain?" do
      it "should return true when domain name is valid" do
        with_factory do |block_factory, transaction_factory|
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          scars.valid_domain?("sushi.sc").should be_true
        end
      end

      it "should raise an error with a message when " do
        with_factory do |block_factory, transaction_factory|
          domain_rule = <<-RULE
          Your domain '123456789012345678901.sc' is not valid

          1. domain name must contain only alphanumerics
          2. domain name must end with one of these suffixes: ["sc"]
          3. domain name length must be between 1 and 20 characters (excluding suffix)
          RULE

          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          expect_raises(Exception, domain_rule) do
            scars.valid_domain?("123456789012345678901.sc")
          end
        end
      end

      it "should raise an error when domain name is longer than 20 characters" do
        with_factory do |block_factory, transaction_factory|
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          expect_raises(Exception) do
            scars.valid_domain?("123456789012345678901.sc")
          end
        end
      end

      it "should raise an error when domain name does not contain a dot" do
        with_factory do |block_factory, transaction_factory|
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          expect_raises(Exception) do
            scars.valid_domain?("nodotsc")
          end
        end
      end

      it "should raise an error when domain name does not end with .sc prefix" do
        with_factory do |block_factory, transaction_factory|
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          expect_raises(Exception) do
            scars.valid_domain?("domain.rt")
          end
        end
      end

      it "should raise an error when domain name contains empty spaces" do
        with_factory do |block_factory, transaction_factory|
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          expect_raises(Exception) do
            scars.valid_domain?("h e l l o.sc")
          end
        end
      end

      it "should work when using Self.valid_domain?" do
        Scars.valid_domain?("domain.sc").should be_true
      end
    end

    describe "#record" do
      it "should record internal domains" do
        with_factory do |block_factory, transaction_factory|
          chain = block_factory.addBlock([transaction_factory.make_buy_domain_from_platform("domain.sc", 0_i64)]).addBlocks(10).chain
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          scars.record(chain)
          expected = [{"domain.sc" => {domain_name: "domain.sc", address: transaction_factory.sender_wallet.address, status: 0, price: 0_i64}}]
          scars.@domains_internal.reject!(&.empty?).should eq(expected)
        end
      end
    end

    describe "#clear" do
      it "should clear internal domains" do
        with_factory do |block_factory, transaction_factory|
          chain = block_factory.addBlock([transaction_factory.make_buy_domain_from_platform("domain.sc", 0_i64)]).addBlocks(10).chain
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          scars.record(chain)
          expected = [{"domain.sc" => {domain_name: "domain.sc", address: transaction_factory.sender_wallet.address, status: 0, price: 0_i64}}]
          scars.@domains_internal.reject!(&.empty?).should eq(expected)
          scars.clear
          scars.@domains_internal.size.should eq(0)
        end
      end
    end

    describe "#Scars.fee" do
      it "should show the fee for an action" do
        Scars.fee("scars_buy").should eq(100_i64)
        Scars.fee("scars_sell").should eq(10_i64)
        Scars.fee("scars_cancel").should eq(1_i64)
      end

      it "should raise an error if fee type is unknown" do
        expect_raises(Exception, "got unknown action unknown during getting a fee for scars") do
          Scars.fee("unknown").should eq(0_i64)
        end
      end
    end

    describe "#sales" do
      it "should list all the domains that are for sale" do
        with_factory do |block_factory, transaction_factory|
          domain = "domain1.sc"
          txns = [
            transaction_factory.make_buy_domain_from_platform(domain, 0_i64),
            transaction_factory.make_sell_domain(domain, 500_i64),
          ]
          chain = block_factory.addBlock(txns).addBlocks(10).chain
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          scars.record(chain)

          sales = scars.sales
          sales.size.should eq(1)

          result = sales.first
          result["domain_name"].should eq(domain)
          result["address"].should eq(transaction_factory.sender_wallet.address)
          result["status"].should eq(1)
          result["price"].should eq(500_i64)
        end
      end

      it "should return empty list when no domains are for sale" do
        with_factory do |block_factory, transaction_factory|
          scars = Scars.new(Blockchain.new(transaction_factory.sender_wallet))
          scars.sales.size.should eq(0)
        end
      end
    end
  end
  STDERR.puts "< Scars"
end

def onSuccess(result, &block)
  if result.nil?
    fail("value should not be nil")
  else
    yield result
  end
end
