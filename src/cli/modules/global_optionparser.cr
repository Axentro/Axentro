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

module ::Sushi::Interface
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
    @confirmation : Int32 = 1

    @bind_host : String = "0.0.0.0"
    @bind_port : Int32 = 3000
    @public_url : String?
    @database_path : String?

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

    @price : String?
    @domain : String?

    @token : String?

    @config_name : String?

    @node_id : String?

    @premine_path : String?

    enum Options
      # common options
      CONNECT_NODE
      WALLET_PATH
      WALLET_PASSWORD
      # flags
      IS_TESTNET
      IS_PRIVATE
      JSON
      CONFIRMATION
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
      # for blockchain
      HEADER
      # for miners
      PROCESSES
      # for wallet
      ENCRYPTED
      # for scars
      PRICE
      DOMAIN
      # for tokens
      TOKEN
      # for config
      CONFIG_NAME
      # for node
      NODE_ID
      PREMINE
    end

    def create_option_parser(actives : Array(Options)) : OptionParser
      OptionParser.new do |parser|
        parse_node(parser, actives)
        parse_wallet_path(parser, actives)
        parse_password(parser, actives)
        parse_mainnet(parser, actives)
        parse_testnet(parser, actives)
        parse_public(parser, actives)
        parse_private(parser, actives)
        parse_json(parser, actives)
        parse_confirmation(parser, actives)
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
        parse_premine(parser, actives)
      end
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

    private def parse_confirmation(parser : OptionParser, actives : Array(Options))
      parser.on("--confirmation=CONFIRMATION", I18n.translate("cli.options.confirmation")) { |confirmation|
        @confirmation = confirmation.to_i
      } if is_active?(actives, Options::CONFIRMATION)
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
      parser.on("-f FEE", "--fee=FEE", I18n.translate("cli.options.transaction")) { |fee|
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

    private def parse_price(parser : OptionParser, actives : Array(Options))
      parser.on("--price=PRICE", I18n.translate("cli.options.scars.price")) { |price|
        decimal_option(price) do
          @price = price
        end
      } if is_active?(actives, Options::PRICE)
    end

    private def parse_domain(parser : OptionParser, actives : Array(Options))
      parser.on("--domain=DOMAIN", I18n.translate("cli.options.scars.domain")) { |domain|
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

    private def parse_premine(parser : OptionParser, actives : Array(Options))
      parser.on("--premine=PREMINE", I18n.translate("cli.options.premine")) { |premine|
        @premine_path = premine
      } if is_active?(actives, Options::PREMINE)
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

    def __confirmation : Int32
      @confirmation
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

    def __premine : Core::Premine?
      Core::Premine.validate(@premine_path)
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
