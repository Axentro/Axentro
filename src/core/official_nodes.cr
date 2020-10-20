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
  alias OfficialNodesConfig = Hash(String, Hash(String, Array(String)))

  class OfficialNodes
    @config : OfficialNodesConfig

    def self.validate(path : String | Nil)
      path.nil? ? nil : self.new(path)
    end

    def self.default
      official_node_list =
        {
          "testnet" => {
            "fastnodes" => [
              "VDAwZTdkZGNjYjg1NDA1ZjdhYzk1M2ExMDAzNmY5MjUyYjI0MmMwNGJjZWY4NjA3",
            ],
            "slownodes" => [
              "VDAwZTdkZGNjYjg1NDA1ZjdhYzk1M2ExMDAzNmY5MjUyYjI0MmMwNGJjZWY4NjA3",
            ],
          },
          "mainnet" => {
            "fastnodes" => [
              "VDAwZTdkZGNjYjg1NDA1ZjdhYzk1M2ExMDAzNmY5MjUyYjI0MmMwNGJjZWY4NjA3",
            ],
            "slownodes" => [
              "VDAwZTdkZGNjYjg1NDA1ZjdhYzk1M2ExMDAzNmY5MjUyYjI0MmMwNGJjZWY4NjA3",
            ],
          },
        }
      self.new(official_node_list)
    end

    def initialize(@path : String)
      @config = validate(path)
    end

    def initialize(node_list : Hash(String, Hash(String, Array(String))))
      @path = nil
      @config = node_list
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

    private def validate(path : String)
      raise("Official nodes input file must be a valid .yml file - you supplied #{path}") unless File.extname(path) == ".yml"
      content = OfficialNodesConfig.from_yaml(File.read(path))
      content.values.map(&.values).flatten.each do |address|
        raise("The supplied address: #{address} is invalid") unless Address.is_valid?(address)
      end
      content
    end
  end

  include TransactionModels
end
