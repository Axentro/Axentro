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
include Axentro::Core::Controllers
include Axentro::Core::Keys

describe RPCController do
  describe "#exec_internal_post" do
    describe "#create_unsigned_transaction" do
      it "should return the transaction as json when valid" do
        with_factory do |block_factory, transaction_factory|
          senders = [a_decimal_sender(transaction_factory.sender_wallet, "1", "0.0001")]
          recipients = [a_decimal_recipient(transaction_factory.recipient_wallet, "10")]

          payload = {
            call:       "create_unsigned_transaction",
            action:     "send",
            senders:    senders,
            recipients: recipients,
            message:    "",
            token:      TOKEN_DEFAULT,
            kind:       "SLOW",
            version:    "V1",
          }.to_json

          json = JSON.parse(payload)

          with_rpc_exec_internal_post(block_factory.rpc, json) do |result|
            expected_senders = [a_sender(transaction_factory.sender_wallet, 100000000_i64)]
            expected_recipients = [a_recipient(transaction_factory.recipient_wallet, 1000000000_i64)]

            transaction = Transaction.from_json(result)
            transaction.action.should eq("send")
            transaction.prev_hash.should eq("0")
            transaction.message.should eq("")
            transaction.senders.each_with_index do |s, i|
              s.address.should eq(expected_senders[i].address)
              s.amount.should eq(expected_senders[i].amount)
            end
            transaction.recipients.each_with_index do |r, i|
              r.address.should eq(expected_recipients[i].address)
              r.amount.should eq(expected_recipients[i].amount)
            end
            transaction.kind.should eq(TransactionKind::SLOW)
          end
        end
      end
    end

    describe "#unpermitted_call" do
      it "should raise an error: Missing hash key call" do
        with_factory do |block_factory, _|
          payload = {unknown: "unknown"}.to_json
          json = JSON.parse(payload)

          expect_raises(Exception, %{Missing hash key: "call"}) do
            block_factory.rpc.exec_internal_post(json, MockContext.new.unsafe_as(HTTP::Server::Context), {} of String => String)
          end
        end
      end

      it "should return a 403 when the rpc call is unknown" do
        with_factory do |block_factory, _|
          payload = {call: "unknown"}.to_json
          json = JSON.parse(payload)

          with_rpc_exec_internal_post(block_factory.rpc, json, 403) do |result|
            result.should eq("unpermitted call: unknown")
          end
        end
      end
    end
  end

  describe "#exec_internal_get" do
    it "should return an unpermitted call response" do
      with_factory do |block_factory, _|
        with_rpc_exec_internal_get(block_factory.rpc, 403) do |result|
          result.should eq("unpermitted method: GET")
        end
      end
    end
  end
end
