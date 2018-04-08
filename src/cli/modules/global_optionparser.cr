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
    @unconfirmed : Bool = false

    @bind_host : String = "0.0.0.0"
    @bind_port : Int32 = 3000
    @public_url : String?
    @database_path : String?
    @conn_min : Int32 = 5

    @address : String?
    @amount : Int64?
    @action : String?
    @message : String = ""
    @block_index : Int32?
    @transaction_id : String?
    @fee : Int64?

    @header : Bool = false

    @threads : Int32 = 1

    @encrypted : Bool = false

    @price : Int64?
    @domain : String?

    @token : String?

    module Options
      # common options
      CONNECT_NODE    = 0
      WALLET_PATH     = 1
      WALLET_PASSWORD = 2
      # flags
      IS_TESTNET  = 3
      IS_PRIVATE  = 4
      JSON        = 5
      UNCONFIRMED = 6
      # for node setting up
      BIND_HOST     =  7
      BIND_PORT     =  8
      PUBLIC_URL    =  9
      DATABASE_PATH = 10
      CONN_MIN      = 11
      # for transaction
      ADDRESS        = 12
      AMOUNT         = 13
      ACTION         = 14
      MESSAGE        = 15
      BLOCK_INDEX    = 16
      TRANSACTION_ID = 17
      FEE            = 18
      # for blockchain
      HEADER = 19
      # for miners
      THREADS = 20
      # for wallet
      ENCRYPTED = 21
      # for scars
      PRICE  = 22
      DOMAIN = 23
      # for tokens
      TOKEN = 24
    end

    def create_option_parser(actives : Array(Int32)) : OptionParser
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

        parser.on("-u", "--unconfirmed", "showing unconfirmed amount") {
          @unconfirmed = true
        } if is_active?(actives, Options::UNCONFIRMED)

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

        parser.on("--conn_min=CONN_MIN", "min # of the first connections when you launch a node. the number is not guaranteed when there are not enough node.") { |conn_min|
          @conn_min = conn_min.to_i
        } if is_active?(actives, Options::CONN_MIN)

        parser.on("-a ADDRESS", "--address=ADDRESS", "public address") { |address|
          @address = address
        } if is_active?(actives, Options::ADDRESS)

        parser.on("-m AMOUNT", "--amount=AMOUNT", "the amount of tokens") { |amount|
          @amount = amount.to_i64
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
          @fee = fee.to_i64
        } if is_active?(actives, Options::FEE)

        parser.on("-h", "--header", "get headers only when get a blockchain or blocks") {
          @header = true
        } if is_active?(actives, Options::HEADER)

        parser.on("--threads=THREADS", "# of the work threads (default is 1)") { |threads|
          @threads = threads.to_i
        } if is_active?(actives, Options::THREADS)

        parser.on("-e", "--encrypted", "set this flag when creating a wallet to create an encrypted wallet") {
          @encrypted = true
        } if is_active?(actives, Options::ENCRYPTED)

        parser.on("--price=PRICE", "buy/sell price for SCARS") { |price|
          @price = price.to_i64
        } if is_active?(actives, Options::PRICE)

        parser.on("--domain=DOMAIN", "specify a domain for SCARS") { |domain|
          @domain = domain
        } if is_active?(actives, Options::DOMAIN)

        parser.on("--token=TOKEN", "specify a target token") { |token|
          @token = token
        } if is_active?(actives, Options::TOKEN)
      end
    end

    def is_active?(actives : Array(Int32), option : Int32) : Bool
      actives.includes?(option)
    end

    def __connect_node : String?
      return @connect_node if @connect_node
      cm.get_s("connect_node")
    end

    def __wallet_path : String?
      return @wallet_path if @wallet_path
      cm.get_s("wallet_path")
    end

    def __wallet_password : String?
      @wallet_password
    end

    def __is_testnet : Bool
      return @is_testnet if @is_testnet_changed
      return cm.get_bool("is_testnet").not_nil! if cm.get_bool("is_testnet")
      @is_testnet
    end

    def __is_private : Bool
      return @is_private if @is_private_changed
      return cm.get_bool("is_private").not_nil! if cm.get_bool("is_private")
      @is_private
    end

    def __json : Bool
      @json
    end

    def __unconfirmed : Bool
      @unconfirmed
    end

    def __bind_host : String
      return @bind_host if @bind_host != "0.0.0.0"
      return cm.get_s("bind_host").not_nil! if cm.get_s("bind_host")
      @bind_host
    end

    def __bind_port : Int32
      return @bind_port if @bind_port != 3000
      return cm.get_i32("bind_port").not_nil! if cm.get_i32("bind_port")
      @bind_port
    end

    def __public_url : String?
      return @public_url if @public_url
      cm.get_s("public_url")
    end

    def __database_path : String?
      return @database_path if @database_path
      cm.get_s("database_path")
    end

    def __conn_min : Int32
      return @conn_min if @conn_min != 5
      return cm.get_i32("conn_min").not_nil! if cm.get_i32("conn_min")
      @conn_min
    end

    def __address : String?
      @address
    end

    def __amount : Int64?
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

    def __fee : Int64?
      @fee
    end

    def __header : Bool
      @header
    end

    def __threads : Int32
      return @threads if @threads != 1
      return cm.get_i32("threads").not_nil! if cm.get_i32("threads")
      @threads
    end

    def __encrypted : Bool
      return @encrypted if @encrypted
      return cm.get_bool("encrypted").not_nil! if cm.get_bool("encrypted")
      @encrypted
    end

    def __price : Int64?
      @price
    end

    def __domain : String?
      @domain
    end

    def __token : String?
      @token
    end

    def cm
      ConfigManager.get_instance
    end
  end
end
