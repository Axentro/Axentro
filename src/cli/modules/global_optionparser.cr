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
  module GlobalOptionParser
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
    @auth_code : String?

    @config_name : String?

    @node_id : String?

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
      # for 2fa
      AUTH_CODE
    end

    def create_option_parser(actives : Array(Options)) : OptionParser
      OptionParser.new do |parser|
        parser.on("-n NODE", "--node=NODE", "a url of the connect node") { |connect_node|
          @connect_node = connect_node
        } if is_active?(actives, Options::CONNECT_NODE)

        parser.on(
          "-w WALLET_PATH",
          "--wallet_path=WALLET_PATH",
          "path to a wallet file (json)"
        ) { |wallet_path| @wallet_path = wallet_path } if is_active?(actives, Options::WALLET_PATH)

        parser.on("--password=PASSWORD", "password for a encrypted wallet") { |password|
          @wallet_password = password
        } if is_active?(actives, Options::WALLET_PASSWORD)

        parser.on("--mainnet", "set network type as mainnet (default is mainnet)") {
          @is_testnet = false
          @is_testnet_changed = true
        } if is_active?(actives, Options::IS_TESTNET)

        parser.on("--testnet", "set network type as testnet (default is mainnet)") {
          @is_testnet = true
          @is_testnet_changed = true
        } if is_active?(actives, Options::IS_TESTNET)

        parser.on("--public", "launch a node in public mode. (default is public mode)") {
          @is_private = false
          @is_private_changed = true
        } if is_active?(actives, Options::IS_PRIVATE)

        parser.on("--private", "launch a node in private mode. it will not be connected from other nodes.") {
          @is_private = true
          @is_private_changed = true
        } if is_active?(actives, Options::IS_PRIVATE)

        parser.on("-j", "--json", "print results as json") {
          @json = true
        } if is_active?(actives, Options::JSON)

        parser.on("--confirmation=CONFIRMATION", "set the length for the confirmation") { |confirmation|
          @confirmation = confirmation.to_i
        } if is_active?(actives, Options::CONFIRMATION)

        parser.on("-h BIND_HOST", "--bind_host=BIND_HOST", "binding host; '0.0.0.0' by default") { |bind_host|
          raise "invalid host: #{bind_host}" unless bind_host.count('.') == 3
          @bind_host = bind_host
        } if is_active?(actives, Options::BIND_HOST)

        parser.on("-p BIND_PORT", "--bind_port=BIND_PORT", "binding port; 3000 by default") { |bind_port|
          @bind_port = bind_port.to_i
        } if is_active?(actives, Options::BIND_PORT)

        parser.on("-u PUBLIC_URL", "--public_url=PUBLIC_URL", "public url of your node that can be accessed from internet. if your node is behind a NAT, you can add --private flag instread of this option") { |public_url|
          @public_url = public_url
        } if is_active?(actives, Options::PUBLIC_URL)

        parser.on("-d DATABASE", "--database=DATABASE", "path to a database (SQLite3)") { |database_path|
          @database_path = database_path
        } if is_active?(actives, Options::DATABASE_PATH)

        parser.on("-a ADDRESS", "--address=ADDRESS", "public address") { |address|
          @address = address
        } if is_active?(actives, Options::ADDRESS)

        parser.on("-m AMOUNT", "--amount=AMOUNT", "the amount of tokens") { |amount|
          decimal_option(amount) do
            @amount = amount
          end
        } if is_active?(actives, Options::AMOUNT)

        parser.on("--action=ACTION", "specify an action name of the transaction") { |action|
          @action = action
        } if is_active?(actives, Options::ACTION)

        parser.on("--message=MESSAGE", "add message into transaction") { |message|
          @message = message
        } if is_active?(actives, Options::MESSAGE)

        parser.on("-i BLOCK_INDEX", "--index=BLOCK_INDEX", "block index") { |block_index|
          @block_index = block_index.to_i
        } if is_active?(actives, Options::BLOCK_INDEX)

        parser.on(
          "-t TRANSACTION_ID",
          "--transaction_id=TRANSACTION_ID",
          "transaction id"
        ) { |transaction_id|
          @transaction_id = transaction_id
        } if is_active?(actives, Options::TRANSACTION_ID)

        parser.on("-f FEE", "--fee=FEE", "the amount of fee") { |fee|
          decimal_option(fee) do
            @fee = fee
          end
        } if is_active?(actives, Options::FEE)

        parser.on("-h", "--header", "get headers only when get a blockchain or blocks") {
          @header = true
        } if is_active?(actives, Options::HEADER)

        parser.on("--process=PROCESSES", "# of the work processes (default is 1)") { |processes|
          @processes = processes.to_i
        } if is_active?(actives, Options::PROCESSES)

        parser.on("-e", "--encrypted", "set this flag when creating a wallet to create an encrypted wallet") {
          @encrypted = true
        } if is_active?(actives, Options::ENCRYPTED)

        parser.on("--price=PRICE", "buy/sell price for SCARS") { |price|
          decimal_option(price) do
            @price = price
          end
        } if is_active?(actives, Options::PRICE)

        parser.on("--domain=DOMAIN", "specify a domain for SCARS") { |domain|
          @domain = domain
        } if is_active?(actives, Options::DOMAIN)

        parser.on("--token=TOKEN", "specify a target token") { |token|
          @token = token
        } if is_active?(actives, Options::TOKEN)

        parser.on("-c", "--config=CONFIG_NAME", "specify a config name") { |name|
          @config_name = name
        } if is_active?(actives, Options::CONFIG_NAME)

        parser.on("--node_id=NODE_ID", "specify a node id") { |node_id|
          @node_id = node_id
        } if is_active?(actives, Options::NODE_ID)

        parser.on("--auth_code=AUTH_CODE", "supply 2fa auth code for transaction") { |auth_code|
          @auth_code = auth_code
        } if is_active?(actives, Options::AUTH_CODE)
      end
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

    def __auth_code : String?
      @auth_code
    end

    def cm
      ConfigManager.get_instance
    end

    def decimal_option(value, &block)
      valid_amount?(value)
      yield value
    rescue e : InvalidBigDecimalException
      puts_error "please supply valid decimal number: #{value}"
      exit -1
    end

    private def with_string_config(name, var)
      return var if var
      cm.get_s(name, @config_name)
    end

    include Logger
    include Common::Validator
  end
end
