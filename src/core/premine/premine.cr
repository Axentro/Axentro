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

module ::Sushi::Core
  include Keys
  include Common::Timestamp
  include Common::Validator

  class Premine
    @config : PremineConfig

    def self.validate(path : String | Nil)
      path.nil? ? nil : self.new(path)
    end

    def initialize(path : String)
      @config = validate(path)
    end

    def get_config
      @config
    end

    def self.transactions(config : PremineConfig)
      recipients = config.addresses.map do |item|
        {address: item["address"], amount: item["amount"].to_s}
      end

      TransactionDecimal.new(
        Transaction.create_id,
        "head",
        [] of Transaction::SenderDecimal,
        recipients,
        "0",           # message
        TOKEN_DEFAULT, # token
        "0",           # prev_hash
        __timestamp,   # timestamp
        0,             # scaled
      ).to_transaction
    end

    private def validate(path : String)
      raise("Premine input file must be a valid .yml file - you supplied #{path}") unless File.extname(path) == ".yml"
      content = PremineConfig.from_yaml(File.read(path))
      content.addresses.each do |item|
        address = item["address"]
        amount = item["amount"]
        raise("The supplied address: #{address} is invalid") unless Address.is_valid?(address)
        valid_amount?(amount, "The supplied amount: #{amount} for address: #{address} - ")
      end
      content
    end
  end

  class PremineConfig
    YAML.mapping(addresses: Array(Hash(String, String)))

    def initialize(@addresses : Array(Hash(String, String)))
    end
  end
end
