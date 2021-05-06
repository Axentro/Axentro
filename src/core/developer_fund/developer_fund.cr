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
  class DeveloperFund
    @config : DeveloperFundConfig

    def self.validate(path : String | Nil)
      path.nil? ? nil : self.new(path)
    end

    def initialize(@path : String)
      @config = validate(path)
    end

    def get_config
      @config
    end

    def set_config(config)
      @config = config
    end

    def get_path
      @path.nil? ? "unknown" : @path
    end

    def get_total_amount : Int64
      @config.addresses.reduce(0_i64) { |total, item| total + scale_i64(item["amount"]) }
    end

    def self.transactions(config : DeveloperFundConfig)
      recipients = config.addresses.map do |item|
        RecipientDecimal.new(item["address"], item["amount"].to_s)
      end

      transaction_id = Transaction.create_id
      [TransactionDecimal.new(
        transaction_id,
        "head",
        [] of Transaction::SenderDecimal,
        recipients,
        [] of Transaction::Asset,
        [] of Transaction::Module,
        [] of Transaction::Input,
        [] of Transaction::Output,
        "",            # linked
        "0",           # message
        TOKEN_DEFAULT, # token
        "0",           # prev_hash
        0,             # timestamp
        0,             # scaled
        TransactionKind::SLOW,
        TransactionVersion::V1
      ).to_transaction]
    end

    private def validate(path : String)
      raise("Developer fund input file must be a valid .yml file - you supplied #{path}") unless File.extname(path) == ".yml"
      content = DeveloperFundConfig.from_yaml(File.read(path))
      content.addresses.each do |item|
        address = item["address"]
        amount = item["amount"]
        raise("The supplied address: #{address} is invalid") unless Address.is_valid?(address)
        valid_amount?(amount, "The supplied amount: #{amount} for address: #{address} - ")
      end
      content
    end
  end

  class DeveloperFundConfig
    include YAML::Serializable
    property addresses : Array(Hash(String, String))

    def initialize(@addresses : Array(Hash(String, String)))
    end
  end

  include TransactionModels
end
