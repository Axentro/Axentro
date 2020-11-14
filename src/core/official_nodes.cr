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

module ::Axentro::Core
  alias OfficialNodesConfig = Hash(String, Array(String))

  class OfficialNodes
    @config : OfficialNodesConfig

    def self.validate(path : String | Nil)
      path.nil? ? nil : self.new(path)
    end

    def initialize(@path : String)
      @config = validate(path)
    end

    def initialize(node_list : Hash(String, Array(String)))
      @path = nil
      @config = node_list
    end

    def get_config
      @config
    end

    def fastnode_address : String?
      fn = @config["fastnodes"]
      fn.size > 0 ? fn.first : nil
    end

    def self.transactions(config : OfficialNodesConfig, coinbases : Array(Core::Transaction)) : Array(Core::Transaction)
      slow = config["slownodes"].map do |address|
        create_transaction(address, "create_official_node_slow")
      end
      fast = config["fastnodes"].map do |address|
        create_transaction(address, "create_official_node_fast")
      end

      transactions = slow + fast

      hashed_transactions = [] of Core::Transaction

      if !coinbases.empty?
        (coinbases + transactions).each_with_index do |t, i|
          unless t.is_coinbase?
            hashed_transactions << t.add_prev_hash((coinbases + hashed_transactions)[i - 1].to_hash)
          end
        end
      else
        ([create_coinbase] + transactions).each_with_index do |t, i|
          hashed_transactions << (t.is_coinbase? ? t : t.add_prev_hash(hashed_transactions[i - 1].to_hash))
        end
      end

      hashed_transactions
    end

    def self.create_transaction(address : String, node_kind : String) : Core::Transaction
      TransactionDecimal.new(
        Transaction.create_id,
        node_kind,
        [] of Transaction::SenderDecimal,
        [{address: address, amount: "0"}],
        "0",           # message
        TOKEN_DEFAULT, # token
        "0",           # prev_hash
        0,             # timestamp
        0,             # scaled
        TransactionKind::SLOW,
        TransactionVersion::V1
      ).to_transaction
    end

    def self.create_coinbase : Core::Transaction
      TransactionDecimal.new(
        Transaction.create_id,
        "head",
        [] of Transaction::SenderDecimal,
        [] of Transaction::RecipientDecimal,
        "0",           # message
        TOKEN_DEFAULT, # token
        "0",           # prev_hash
        0,             # timestamp
        0,             # scaled
        TransactionKind::SLOW,
        TransactionVersion::V1
      ).to_transaction
    end

    def set_config(config)
      @config = config
    end

    def get_path
      @path.nil? ? "unknown" : @path
    end

    private def validate(path : String)
      raise("Official nodes input file must be a valid .yml file - you supplied #{path}") unless File.extname(path) == ".yml"
      content = OfficialNodesConfig.from_yaml(File.read(path))
      content.values.flatten.each do |address|
        raise("The supplied address: #{address} is invalid") unless Address.is_valid?(address)
      end
      content
    end
  end

  include TransactionModels
end
