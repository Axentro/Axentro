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
require "../blockchain/*"
require "../blockchain/domain_model/*"

module ::Axentro::Core
  class MigrationSupport
    def initialize(@connection : DB::Connection); end

    def transactions_by_query(query, *args)
      block_transactions = {} of Int64 => Array(Transaction)
      @connection.query(query, args: args.to_a) do |rows|
        rows.each do
          t_id = rows.read(String)
          rows.read(Int32)
          block_id = rows.read(Int64)
          action = rows.read(String)
          message = rows.read(String)
          token = rows.read(String)
          prev_hash = rows.read(String)
          timestamp = rows.read(Int64)
          scaled = rows.read(Int32)
          kind_string = rows.read(String)
          kind = kind_string == "SLOW" ? TransactionKind::SLOW : TransactionKind::FAST
          version_string = rows.read(String)
          version = TransactionVersion.parse(version_string)

          t = Transaction.new(t_id, action, [] of Transaction::Sender, [] of Transaction::Recipient, message, token, prev_hash, timestamp, scaled, kind, version)
          t.set_senders(get_senders(t))
          t.set_recipients(get_recipients(t))
          block_transactions[block_id] ||= [] of Transaction
          block_transactions[block_id] << t
        end
      end
      block_transactions
    end

    def get_senders(t : Transaction) : Transaction::Senders
      senders = [] of Transaction::Sender
      @connection.query "select * from senders where transaction_id = ? order by idx", t.id do |rows|
        rows.each do
          rows.read(String?)
          rows.read(Int64)
          rows.read(Int32)
          senders << {
            address:    rows.read(String),
            public_key: rows.read(String),
            amount:     rows.read(Int64),
            fee:        rows.read(Int64),
            signature:  rows.read(String),
          }
        end
      end
      senders
    end

    def get_recipients(t : Transaction) : Transaction::Recipients
      recipients = [] of Transaction::Recipient
      @connection.query "select * from recipients where transaction_id = ? order by idx", t.id do |rows|
        rows.each do
          rows.read(String)
          rows.read(Int64)
          rows.read(Int32)
          recipients << {
            address: rows.read(String),
            amount:  rows.read(Int64),
          }
        end
      end
      recipients
    end
  end
end
