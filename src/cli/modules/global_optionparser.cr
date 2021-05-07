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

module ::Axentro::Interface
  class GlobalOptionParser
    @@instance : GlobalOptionParser? = nil

    def self.op : GlobalOptionParser
      @@instance ||= GlobalOptionParser.new
      @@instance.not_nil!
    end

    @connect_node : String?
    @wallet_path : String?
    @wallet_password : String?

    @is_testnet : Bool = false
    @is_testnet_changed = false
    @is_private : Bool = false
    @is_private_changed = false
    @json : Bool = false

    @bind_host : String = "0.0.0.0"
    @bind_port : Int32 = 3000
    @public_url : String?
    @database_path : String?
    @max_miners : Int32 = 512
    @max_nodes : Int32 = 512

    @address : String?
    @amount : String?
    @action : String?
    @message : String = ""
    @block_index : Int32?
    @transaction_id : String?
    @fee : String?

    @header : Bool = false

    @processes : Int32 = 1

    @encrypted : Bool = false
    @seed : String?
    @derivation : String?

    @price : String?
    @domain : String?

    @token : String?

    @config_name : String?

    @node_id : String?

    @developer_fund_path : String?
    @fastnode : Bool = false
    @official_nodes_path : String?
    @exit_if_unofficial : Bool = false

    @security_level_percentage = 20_i64
    @sync_chunk_size = 100

    @is_fast_transaction : Bool = false
    @record_nonces : Bool = false

    @whitelist : Array(String) = [] of String
    @whitelist_message : String = ""
    @metrics_whitelist : Array(String) = [] of String

    @asset_id : String?
    @asset_name : String?
    @asset_description : String?
    @asset_media_location : String?
    @asset_locked : Bool = false

    enum Options
      # common options
      CONNECT_NODE
      WALLET_PATH
      WALLET_PASSWORD
      # flags
      IS_TESTNET
      IS_PRIVATE
      JSON
      # for node setting up
      BIND_HOST
      BIND_PORT
      PUBLIC_URL
      DATABASE_PATH
      # for transaction
      ADDRESS
      AMOUNT
      ACTION
      MESSAGE
      BLOCK_INDEX
      TRANSACTION_ID
      FEE
      IS_FAST_TRANSACTION
      # for blockchain
      HEADER
      # for miners
      PROCESSES
      # for wallet
      ENCRYPTED
      SEED
      DERIVATION
      # for hra
      PRICE
      DOMAIN
      # for tokens
      TOKEN
      # for config
      CONFIG_NAME
      # for node
      NODE_ID
      DEVELOPER_FUND
      FASTNODE
      OFFICIAL_NODES
      SECURITY_LEVEL_PERCENTAGE
      SYNC_CHUNK_SIZE
      MAX_MINERS
      MAX_PRIVATE_NODES
      EXIT_IF_UNOFFICIAL
      RECORD_NONCES
      WHITELIST
      WHITELIST_MESSAGE
      # for assets
      ASSET_ID
      ASSET_NAME
      ASSET_DESCRIPTION
      ASSET_MEDIA_LOCATION
      ASSET_LOCKED
      METRICS_WHITELIST
    end

    def create_option_parser(actives : Array(Options)) : OptionParser
      OptionParser.new do |parser|
        parse_version(parser)
        parse_node(parser, actives)
        parse_wallet_path(parser, actives)
        parse_password(parser, actives)
        parse_mainnet(parser, actives)
        parse_testnet(parser, actives)
        parse_public(parser, actives)
        parse_private(parser, actives)
        parse_json(parser, actives)
        parse_bind_host(parser, actives)
        parse_bind_port(parser, actives)
        parse_public_url(parser, actives)
        parse_database(parser, actives)
        parse_address(parser, actives)
        parse_amount(parser, actives)
        parse_action(parser, actives)
        parse_message(parser, actives)
        parse_block_index(parser, actives)
        parse_transaction_id(parser, actives)
        parse_fee(parser, actives)
        parse_header(parser, actives)
        parse_processes(parser, actives)
        parse_encrypted(parser, actives)
        parse_price(parser, actives)
        parse_domain(parser, actives)
        parse_token(parser, actives)
        parse_config_name(parser, actives)
        parse_node_id(parser, actives)
        parse_developer_fund(parser, actives)
        parse_fast_node(parser, actives)
        parse_official_nodes(parser, actives)
        parse_if_unofficial_nodes(parser, actives)
        parse_security_level_percentage(parser, actives)
        parse_sync_chunk_size(parser, actives)
        parse_slow_transaction(parser, actives)
        parse_fast_transaction(parser, actives)
        parse_max_miners(parser, actives)
        parse_max_private_nodes(parser, actives)
        parse_seed(parser, actives)
        parse_derivation(parser, actives)
        parse_record_nonces(parser, actives)
        parse_whitelist(parser, actives)
        parse_whitelist_message(parser, actives)
        parse_asset_id(parser, actives)
        parse_asset_name(parser, actives)
        parse_asset_description(parser, actives)
        parse_asset_media_location(parser, actives)
        parse_asset_locked(parser, actives)
        parse_metrics_whitelist(parser, actives)
      end
    end

    private def parse_version(parser : OptionParser)
      parser.on("-v", "--version", "version") {
        puts {{ read_file("#{__DIR__}/../../../version.txt") }}
        exit 0
      }
    end

    private def parse_node(parser : OptionParser, actives : Array(Options))
      parser.on("-n NODE", "--node=NODE", I18n.translate("cli.options.node.url")) { |connect_node|
        @connect_node = connect_node
      } if is_active?(actives, Options::CONNECT_NODE)
    end

    private def parse_wallet_path(parser : OptionParser, actives : Array(Options))
      parser.on(
        "-w WALLET_PATH",
        "--wallet_path=WALLET_PATH",
        I18n.translate("cli.options.wallet")
      ) { |wallet_path| @wallet_path = wallet_path } if is_active?(actives, Options::WALLET_PATH)
    end

    private def parse_password(parser : OptionParser, actives : Array(Options))
      parser.on("--password=PASSWORD", I18n.translate("cli.options.password")) { |password|
        @wallet_password = password
      } if is_active?(actives, Options::WALLET_PASSWORD)
    end

    private def parse_mainnet(parser : OptionParser, actives : Array(Options))
      parser.on("--mainnet", I18n.translate("cli.options.mainnet")) {
        @is_testnet = false
        @is_testnet_changed = true
      } if is_active?(actives, Options::IS_TESTNET)
    end

    private def parse_testnet(parser : OptionParser, actives : Array(Options))
      parser.on("--testnet", I18n.translate("cli.options.testnet")) {
        @is_testnet = true
        @is_testnet_changed = true
      } if is_active?(actives, Options::IS_TESTNET)
    end

    private def parse_if_unofficial_nodes(parser : OptionParser, actives : Array(Options))
      parser.on("--exit-if-unofficial", I18n.translate("cli.options.unofficial")) {
        @exit_if_unofficial = true
      } if is_active?(actives, Options::EXIT_IF_UNOFFICIAL)
    end

    private def parse_public(parser : OptionParser, actives : Array(Options))
      parser.on("--public", I18n.translate("cli.options.public.mode")) {
        @is_private = false
        @is_private_changed = true
      } if is_active?(actives, Options::IS_PRIVATE)
    end

    private def parse_private(parser : OptionParser, actives : Array(Options))
      parser.on("--private", I18n.translate("cli.options.private")) {
        @is_private = true
        @is_private_changed = true
      } if is_active?(actives, Options::IS_PRIVATE)
    end

    private def parse_json(parser : OptionParser, actives : Array(Options))
      parser.on("-j", "--json", I18n.translate("cli.options.json")) {
        @json = true
      } if is_active?(actives, Options::JSON)
    end

    private def parse_bind_host(parser : OptionParser, actives : Array(Options))
      parser.on("-h BIND_HOST", "--bind_host=BIND_HOST", I18n.translate("cli.options.binding.host")) { |bind_host|
        raise "invalid host: #{bind_host}" unless bind_host.count('.') == 3
        @bind_host = bind_host
      } if is_active?(actives, Options::BIND_HOST)
    end

    private def parse_bind_port(parser : OptionParser, actives : Array(Options))
      parser.on("-p BIND_PORT", "--bind_port=BIND_PORT", I18n.translate("cli.options.binding.port")) { |bind_port|
        @bind_port = bind_port.to_i
      } if is_active?(actives, Options::BIND_PORT)
    end

    private def parse_public_url(parser : OptionParser, actives : Array(Options))
      parser.on("-u PUBLIC_URL", "--public_url=PUBLIC_URL", I18n.translate("cli.options.public.url")) { |public_url|
        @public_url = public_url
      } if is_active?(actives, Options::PUBLIC_URL)
    end

    private def parse_database(parser : OptionParser, actives : Array(Options))
      parser.on("-d DATABASE", "--database=DATABASE", I18n.translate("cli.options.database")) { |database_path|
        @database_path = database_path
      } if is_active?(actives, Options::DATABASE_PATH)
    end

    private def parse_address(parser : OptionParser, actives : Array(Options))
      parser.on("-a ADDRESS", "--address=ADDRESS", I18n.translate("cli.options.address")) { |address|
        @address = address
      } if is_active?(actives, Options::ADDRESS)
    end

    private def parse_amount(parser : OptionParser, actives : Array(Options))
      parser.on("-m AMOUNT", "--amount=AMOUNT", I18n.translate("cli.options.token.amount")) { |amount|
        decimal_option(amount) do
          @amount = amount
        end
      } if is_active?(actives, Options::AMOUNT)
    end

    private def parse_action(parser : OptionParser, actives : Array(Options))
      parser.on("--action=ACTION", I18n.translate("cli.options.action")) { |action|
        @action = action
      } if is_active?(actives, Options::ACTION)
    end

    private def parse_message(parser : OptionParser, actives : Array(Options))
      parser.on("--message=MESSAGE", I18n.translate("cli.options.message")) { |message|
        @message = message
      } if is_active?(actives, Options::MESSAGE)
    end

    private def parse_block_index(parser : OptionParser, actives : Array(Options))
      parser.on("-i BLOCK_INDEX", "--index=BLOCK_INDEX", I18n.translate("cli.options.block")) { |block_index|
        @block_index = block_index.to_i
      } if is_active?(actives, Options::BLOCK_INDEX)
    end

    private def parse_transaction_id(parser : OptionParser, actives : Array(Options))
      parser.on(
        "-t TRANSACTION_ID",
        "--transaction_id=TRANSACTION_ID",
        I18n.translate("cli.options.transaction")
      ) { |transaction_id|
        @transaction_id = transaction_id
      } if is_active?(actives, Options::TRANSACTION_ID)
    end

    private def parse_fee(parser : OptionParser, actives : Array(Options))
      parser.on("-f FEE", "--fee=FEE", I18n.translate("cli.options.fee")) { |fee|
        decimal_option(fee) do
          @fee = fee
        end
      } if is_active?(actives, Options::FEE)
    end

    private def parse_header(parser : OptionParser, actives : Array(Options))
      parser.on("-h", "--header", I18n.translate("cli.options.headers")) {
        @header = true
      } if is_active?(actives, Options::HEADER)
    end

    private def parse_processes(parser : OptionParser, actives : Array(Options))
      parser.on("--process=PROCESSES", I18n.translate("cli.options.processes")) { |processes|
        @processes = processes.to_i
      } if is_active?(actives, Options::PROCESSES)
    end

    private def parse_encrypted(parser : OptionParser, actives : Array(Options))
      parser.on("-e", "--encrypted", I18n.translate("cli.options.encrypted")) {
        @encrypted = true
      } if is_active?(actives, Options::ENCRYPTED)
    end

    private def parse_seed(parser : OptionParser, actives : Array(Options))
      parser.on("--seed=SEED", I18n.translate("cli.options.seed")) { |seed|
        @seed = seed
      } if is_active?(actives, Options::SEED)
    end

    private def parse_derivation(parser : OptionParser, actives : Array(Options))
      parser.on("--derivation=\"m/0'\"", I18n.translate("cli.options.derivation")) { |derivation|
        @derivation = derivation
      } if is_active?(actives, Options::DERIVATION)
    end

    private def parse_price(parser : OptionParser, actives : Array(Options))
      parser.on("--price=PRICE", I18n.translate("cli.options.hra.price")) { |price|
        decimal_option(price) do
          @price = price
        end
      } if is_active?(actives, Options::PRICE)
    end

    private def parse_domain(parser : OptionParser, actives : Array(Options))
      parser.on("--domain=DOMAIN", I18n.translate("cli.options.hra.domain")) { |domain|
        @domain = domain
      } if is_active?(actives, Options::DOMAIN)
    end

    private def parse_token(parser : OptionParser, actives : Array(Options))
      parser.on("--token=TOKEN", I18n.translate("cli.options.token.kind")) { |token|
        @token = token
      } if is_active?(actives, Options::TOKEN)
    end

    private def parse_config_name(parser : OptionParser, actives : Array(Options))
      parser.on("-c", "--config=CONFIG_NAME", I18n.translate("cli.options.config")) { |name|
        @config_name = name
      } if is_active?(actives, Options::CONFIG_NAME)
    end

    private def parse_node_id(parser : OptionParser, actives : Array(Options))
      parser.on("--node_id=NODE_ID", I18n.translate("cli.options.node.id")) { |node_id|
        @node_id = node_id
      } if is_active?(actives, Options::NODE_ID)
    end

    private def parse_developer_fund(parser : OptionParser, actives : Array(Options))
      parser.on("--developer-fund=DEVELOPER_FUND", I18n.translate("cli.options.developer_fund")) { |developer_fund|
        @developer_fund_path = developer_fund
      } if is_active?(actives, Options::DEVELOPER_FUND)
    end

    private def parse_official_nodes(parser : OptionParser, actives : Array(Options))
      parser.on("--official-nodes=OFFICAL_NODES", I18n.translate("cli.options.official_nodes")) { |official_nodes|
        @official_nodes_path = official_nodes
      } if is_active?(actives, Options::OFFICIAL_NODES)
    end

    private def parse_fast_node(parser : OptionParser, actives : Array(Options))
      parser.on("--fastnode", I18n.translate("cli.options.fastnode")) {
        @fastnode = true
      } if is_active?(actives, Options::FASTNODE)
    end

    private def parse_security_level_percentage(parser : OptionParser, actives : Array(Options))
      parser.on("--security-level-percentage=PERCENT_VALUE", I18n.translate("cli.options.security_level_percentage")) { |slp|
        @security_level_percentage = Math.max(slp.to_i64, 2_i64)
      } if is_active?(actives, Options::SECURITY_LEVEL_PERCENTAGE)
    end

    private def parse_sync_chunk_size(parser : OptionParser, actives : Array(Options))
      parser.on("--sync-chunk-size=VALUE", I18n.translate("cli.options.sync_chunk_size")) { |sc|
        raise "sync chunk size must be greater than 0" if sc.to_i <= 0
        @sync_chunk_size = sc.to_i
      } if is_active?(actives, Options::SYNC_CHUNK_SIZE)
    end

    private def parse_record_nonces(parser : OptionParser, actives : Array(Options))
      parser.on("--record-nonces", I18n.translate("cli.options.record_nonces")) {
        @record_nonces = true
      } if is_active?(actives, Options::RECORD_NONCES)
    end

    private def parse_slow_transaction(parser : OptionParser, actives : Array(Options))
      parser.on("--slow-transaction", I18n.translate("cli.options.slow_transaction")) {
        @is_fast_transaction = false
        @is_fast_transaction_changed = true
      } if is_active?(actives, Options::IS_FAST_TRANSACTION)
    end

    private def parse_fast_transaction(parser : OptionParser, actives : Array(Options))
      parser.on("--fast-transaction", I18n.translate("cli.options.fast_transaction")) {
        @is_fast_transaction = true
        @is_fast_transaction_changed = true
      } if is_active?(actives, Options::IS_FAST_TRANSACTION)
    end

    private def parse_max_miners(parser : OptionParser, actives : Array(Options))
      parser.on("--max-miners=VALUE", I18n.translate("cli.options.max_miners")) { |v|
        @max_miners = v.to_i
      } if is_active?(actives, Options::MAX_MINERS)
    end

    private def parse_whitelist(parser : OptionParser, actives : Array(Options))
      parser.on("--whitelist=VALUE", I18n.translate("cli.options.whitelist")) { |v|
        @whitelist = v.split(",").uniq
      } if is_active?(actives, Options::WHITELIST)
    end

    private def parse_whitelist_message(parser : OptionParser, actives : Array(Options))
      parser.on("--whitelist-message=VALUE", I18n.translate("cli.options.whitelist_message")) { |v|
        @whitelist_message = v
      } if is_active?(actives, Options::WHITELIST_MESSAGE)
    end

    private def parse_metrics_whitelist(parser : OptionParser, actives : Array(Options))
      parser.on("--metrics-whitelist=VALUE", I18n.translate("cli.options.metrics_whitelist")) { |v|
        @metrics_whitelist = v.split(",").uniq
      } if is_active?(actives, Options::METRICS_WHITELIST)
    end

    private def parse_max_private_nodes(parser : OptionParser, actives : Array(Options))
      parser.on("--max-private-nodes=VALUE", I18n.translate("cli.options.max_private_nodes")) { |v|
        @max_nodes = v.to_i
      } if is_active?(actives, Options::MAX_PRIVATE_NODES)
    end

    private def parse_asset_id(parser : OptionParser, actives : Array(Options))
      parser.on("--asset-id=VALUE", I18n.translate("cli.options.asset_id")) { |v|
        @asset_id = v
      } if is_active?(actives, Options::ASSET_ID)
    end

    private def parse_asset_name(parser : OptionParser, actives : Array(Options))
      parser.on("--asset-name=VALUE", I18n.translate("cli.options.asset_name")) { |v|
        @asset_name = v
      } if is_active?(actives, Options::ASSET_NAME)
    end

    private def parse_asset_description(parser : OptionParser, actives : Array(Options))
      parser.on("--asset-description=VALUE", I18n.translate("cli.options.asset_description")) { |v|
        @asset_description = v
      } if is_active?(actives, Options::ASSET_DESCRIPTION)
    end

    private def parse_asset_media_location(parser : OptionParser, actives : Array(Options))
      parser.on("--asset-media-location=VALUE", I18n.translate("cli.options.asset_media_location")) { |v|
        @asset_media_location = v
      } if is_active?(actives, Options::ASSET_MEDIA_LOCATION)
    end

    private def parse_asset_locked(parser : OptionParser, actives : Array(Options))
      parser.on("--lock-asset", I18n.translate("cli.options.asset_locked")) { |_|
        @asset_locked = true
      } if is_active?(actives, Options::ASSET_LOCKED)
    end

    def is_active?(actives : Array(Options), option : Options) : Bool
      actives.includes?(option)
    end

    def __connect_node : String?
      with_string_config("connect_node", @connect_node)
    end

    def __wallet_path : String?
      with_string_config("wallet_path", @wallet_path)
    end

    def __wallet_password : String?
      with_string_config("wallet_password", @wallet_password)
    end

    def __is_testnet : Bool
      return @is_testnet if @is_testnet_changed
      return cm.get_bool("is_testnet", @config_name).not_nil! if cm.get_bool("is_testnet", @config_name)
      @is_testnet
    end

    def __is_private : Bool
      return @is_private if @is_private_changed
      return cm.get_bool("is_private", @config_name).not_nil! if cm.get_bool("is_private", @config_name)
      @is_private
    end

    def __json : Bool
      @json
    end

    def __bind_host : String
      return @bind_host if @bind_host != "0.0.0.0"
      return cm.get_s("bind_host", @config_name).not_nil! if cm.get_s("bind_host", @config_name)
      @bind_host
    end

    def __bind_port : Int32
      return @bind_port if @bind_port != 3000
      return cm.get_i32("bind_port", @config_name).not_nil! if cm.get_i32("bind_port", @config_name)
      @bind_port
    end

    def __public_url : String?
      with_string_config("public_url", @public_url)
    end

    def __database_path : String?
      with_string_config("database_path", @database_path)
    end

    def __address : String?
      with_string_config("address", @address)
    end

    def __asset_id : String?
      @asset_id
    end

    def __asset_name : String?
      @asset_name
    end

    def __asset_description : String?
      @asset_description
    end

    def __asset_media_location : String?
      @asset_media_location
    end

    def __asset_locked : Bool
      @asset_locked
    end

    def __whitelist : Array(String)
      @whitelist
    end

    def __whitelist_message : String
      @whitelist_message
    end

    def __metrics_whitelist : Array(String)
      @metrics_whitelist
    end

    def __amount : String?
      @amount
    end

    def __action : String?
      @action
    end

    def __message : String
      @message
    end

    def __block_index : Int32?
      @block_index
    end

    def __transaction_id : String?
      @transaction_id
    end

    def __fee : String?
      @fee
    end

    def __header : Bool
      @header
    end

    def __processes : Int32
      return @processes if @processes != 1
      return cm.get_i32("processes", @config_name).not_nil! if cm.get_i32("processes", @config_name)
      @processes
    end

    def __encrypted : Bool
      return @encrypted if @encrypted
      return cm.get_bool("encrypted", @config_name).not_nil! if cm.get_bool("encrypted", @config_name)
      @encrypted
    end

    def __seed : String?
      @seed
    end

    def __derivation : String?
      @derivation
    end

    def __price : String?
      @price
    end

    def __domain : String?
      with_string_config("domain", @domain)
    end

    def __token : String?
      @token
    end

    def __name : String?
      @config_name
    end

    def __node_id : String?
      @node_id
    end

    def __developer_fund : Core::DeveloperFund?
      Core::DeveloperFund.validate(@developer_fund_path)
    end

    def __official_nodes : Core::OfficialNodes?
      Core::OfficialNodes.validate(@official_nodes_path)
    end

    def __fastnode : Bool
      @fastnode
    end

    def __exit_if_unofficial : Bool
      @exit_if_unofficial
    end

    def __security_level_percentage : Int64
      @security_level_percentage
    end

    def __sync_chunk_size : Int32
      @sync_chunk_size
    end

    def __record_nonces : Bool
      @record_nonces
    end

    def __max_miners : Int32
      @max_miners
    end

    def __max_nodes : Int32
      @max_nodes
    end

    def __is_fast_transaction : Bool
      return @is_fast_transaction if @is_fast_transaction_changed
      return cm.get_bool("is_fast_transaction", @config_name).not_nil! if cm.get_bool("is_fast_transaction", @config_name)
      @is_fast_transaction
    end

    def cm
      ConfigManager.get_instance
    end

    def decimal_option(value, &block)
      valid_amount?(value)
      yield value
    rescue e : InvalidBigDecimalException
      puts_error I18n.translate("cli.errors.decimal", {value: value})
    end

    private def with_string_config(name, var)
      return var if var
      cm.get_s(name, @config_name)
    end

    include Logger
    include Common::Validator
  end

  alias G = GlobalOptionParser
  alias Options = G::Options
end
