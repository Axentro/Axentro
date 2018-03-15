require "./../../spec_helper.cr"
require "./../utils"

include Sushi::Core::Models
include Sushi::Core
include Units::Utils

describe Scars do
  describe "#get" do
    it "should return nil if the number internal domains is less than confirmations" do
      with_factory do |block_factory|
        chain = block_factory.addBlock.chain
        scars = Scars.new
        scars.record(chain)
        scars.get("domain1.sc").should be_nil
      end
    end

    it "should return nil if the domain is not found" do
      with_factory do |block_factory|
        chain = block_factory.addBlocks(10).chain
        scars = Scars.new
        scars.record(chain)
        scars.get("domain1.sc").should be_nil
      end
    end

    it "should return domain info if the domain is found" do
      with_factory do |block_factory, transaction_factory|
        domain = "domain1.sc"
        chain = block_factory.addBlock([transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]).addBlocks(10).chain
        scars = Scars.new
        scars.record(chain)

        onSuccess(scars.get(domain)) do |result|
          result["domain_name"].should eq(domain)
          result["address"].should eq(transaction_factory.sender_wallet.address)
          result["status"].should eq(0)
          result["price"].should eq(0_i64)
        end
      end
    end

    describe "#get_unconfirmed" do
      it "should return nil if the domain is not found" do
        with_factory do |block_factory|
          chain = block_factory.addBlock.chain
          scars = Scars.new
          scars.record(chain)
          scars.get_unconfirmed("domain1.sc", chain.last.transactions).should be_nil
        end
      end

      it "should return the domain info for unconfirmed domains" do
        with_factory do |block_factory, transaction_factory|
          domain = "domain1.sc"
          transactions = [transaction_factory.make_buy_domain_from_platform(domain, 0_i64)]
          chain = block_factory.addBlock(transactions).addBlocks(2).chain
          scars = Scars.new
          scars.record(chain)

          onSuccess(scars.get_unconfirmed(domain, transactions)) do |result|
            result["domain_name"].should eq(domain)
            result["address"].should eq(transaction_factory.sender_wallet.address)
            result["status"].should eq(0)
            result["price"].should eq(0_i64)
          end
        end
      end
    end

    it "should return scars #actions" do
      Scars.new.actions.should eq(["scars_buy", "scars_sell"])
    end

    describe "#related" do
      it "should return true if action is a scars related action" do
        Scars.new.related?("scars_buy").should be_true
      end
      it "should return false if the action is not a scars related action" do
        Scars.new.related?("not_related").should be_false
      end
    end

    describe "#valid_buy?" do
      it "should return true when domain is a valid buy from platform" do
        with_factory do |block_factory, transaction_factory|
          tx1 = transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64)
          Scars.new.valid_buy?(tx1, [] of Transaction)
        end
      end

      it "should return true when domain is a valid buy from seller" do
        with_factory do |block_factory, transaction_factory|
          txns = [
            transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64),
            transaction_factory.make_sell_domain("domain1.sc", 500_i64),
          ]

          tx1 = transaction_factory.make_buy_domain_from_seller("domain1.sc", 500_i64)
          Scars.new.valid_buy?(tx1, txns)
        end
      end

      it "should raise error when domain name not for sale" do
        with_factory do |block_factory, transaction_factory|
          txns = [
            transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64),
          ]

          tx1 = transaction_factory.make_buy_domain_from_seller("domain1.sc", 500_i64)
          expect_raises(Exception, "domain domain1.sc is not for sale now") do
            Scars.new.valid_buy?(tx1, txns)
          end
        end
      end

      it "should raise error when trying to buy a domain from seller that has not been bought by anybody yet" do
        with_factory do |block_factory, transaction_factory|
          tx1 = transaction_factory.make_buy_domain_from_seller("domain1.sc", 500_i64)
          expect_raises(Exception, "you cannot set a recipient since no body has bought the domain: domain1.sc") do
            Scars.new.valid_buy?(tx1, [] of Transaction)
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
          expect_raises(Exception, "you have to the set a domain owner as a recipient") do
            Scars.new.valid_buy?(tx1, txns)
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
          expect_raises(Exception, "you cannot set multiple recipients") do
            Scars.new.valid_buy?(tx1, txns)
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
          expect_raises(Exception, "domain address mismatch: #{actual} vs #{expected}") do
            Scars.new.valid_buy?(tx1, txns)
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
          expect_raises(Exception, "the supplied price 0 is different to expected price 500") do
            Scars.new.valid_buy?(tx1, txns)
          end
        end
      end
    end

    describe "#valid_sell?" do
      it "should return true on valid sell" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64)]

          tx1 = transaction_factory.make_sell_domain("domain1.sc", 500_i64)
          Scars.new.valid_sell?(tx1, txns).should be_true
        end
      end

      it "should return error when no recipient set" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64)]

          tx1 = transaction_factory.make_sell_domain("domain1.sc", 500_i64, [] of Recipient)
          expect_raises(Exception, "you have to set one recipient") do
            Scars.new.valid_sell?(tx1, txns)
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
          expect_raises(Exception, "address mistach for scars_sell: expected #{actual} but got #{expected}") do
            Scars.new.valid_sell?(tx1, txns)
          end
        end
      end

      it "should return error when recipient price does not match sender price" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64)]

          recipients = [a_recipient(transaction_factory.sender_wallet, 200_i64)]
          tx1 = transaction_factory.make_sell_domain("domain1.sc", 500_i64, recipients)

          expect_raises(Exception, "price mistach for scars_sell: expected 500 but got 200") do
            Scars.new.valid_sell?(tx1, txns)
          end
        end
      end

      it "should return error when domain name not found" do
        with_factory do |block_factory, transaction_factory|
          tx1 = transaction_factory.make_sell_domain("domain1.sc", 500_i64)

          expect_raises(Exception, "domain domain1.sc not found") do
            Scars.new.valid_sell?(tx1, [] of Transaction)
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
          expect_raises(Exception, "domain address mismatch: expected #{actual} but got #{expected}") do
            Scars.new.valid_sell?(tx1, txns)
          end
        end
      end

      it "should return error when selling price is not greater than 0" do
        with_factory do |block_factory, transaction_factory|
          txns = [transaction_factory.make_buy_domain_from_platform("domain1.sc", 0_i64)]
          tx1 = transaction_factory.make_sell_domain("domain1.sc", -1_i64)

          expect_raises(Exception, "the selling price must be 0 or higher") do
            Scars.new.valid_sell?(tx1, txns)
          end
        end
      end
    end

    describe "#valid_domain?" do
      it "should return true when domain name is valid" do
        Scars.new.valid_domain?("sushi.sc").should be_true
      end

      it "should raise an error when domain name is longer than 20 characters" do
        expect_raises(Exception, "domain length must be shorter than 20 characters") do
          Scars.new.valid_domain?("123456789012345678901.sc")
        end
      end

      it "should raise an error when domain name does not contain a dot" do
        expect_raises(Exception, "domain name must contain at least one dot") do
          Scars.new.valid_domain?("nodotsc")
        end
      end

      it "should raise an error when domain name contains empty spaces before the dot" do
        expect_raises(Exception, "domain must not contain any empty spaces before the dot") do
          Scars.new.valid_domain?(".sc")
        end
      end

      it "should raise an error when domain name does not end with .sc prefix" do
        expect_raises(Exception, "domain must end with [\"sc\"] (rt)") do
          Scars.new.valid_domain?("domain.rt")
        end
      end

      pending "should raise an error when domain name contains empty spaces" do
        expect_raises(Exception, "domain must not contain any empty spaces") do
          Scars.new.valid_domain?("h e l l o.sc")
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