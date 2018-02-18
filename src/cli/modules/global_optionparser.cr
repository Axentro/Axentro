module ::Sushi::Interface
  module GlobalOptionParser
    @connect_node : String?
    @wallet_path : String?
    @wallet_password : String?

    @is_testnet : Bool = false
    @is_private : Bool = false
    @json : Bool = false
    @unconfirmed : Bool = false

    @bind_host : String = "0.0.0.0"
    @bind_port : Int32 = 3000
    @public_url : String?
    @database_path : String?
    @conn_min : Int32 = 5

    @address : String?
    @amount : Int64?
    @message : String = ""
    @block_index : Int32?
    @transaction_id : String?

    @header : Bool = false

    @threads : Int32 = 1

    @encrypted : Bool = false

    module Options
      # common options
      CONNECT_NODE    = 0x00000001
      WALLET_PATH     = 0x00000002
      WALLET_PASSWORD = 0x00000003
      # flags
      IS_TESTNET  = 0x00000100
      IS_PRIVATE  = 0x00000200
      JSON        = 0x00000300
      UNCONFIRMED = 0x00000400
      # for node setting up
      BIND_HOST     = 0x00000010
      BIND_PORT     = 0x00000020
      PUBLIC_URL    = 0x00000030
      DATABASE_PATH = 0x00000040
      CONN_MIN      = 0x00000050
      # for transaction
      ADDRESS        = 0x00001000
      AMOUNT         = 0x00002000
      MESSAGE        = 0x00003000
      BLOCK_INDEX    = 0x00004000
      TRANSACTION_ID = 0x00005000
      # for blockchain
      HEADER = 0x00010000
      # for miners
      THREADS = 0x00100000
      # for wallet
      ENCRYPTED = 0x01000000
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

        parser.on("--testnet", "set network type as testnet (default is mainnet)") {
          @is_testnet = true
        } if is_active?(actives, Options::IS_TESTNET)

        parser.on("--private", "launch a node in private mode. it will not be connected from other nodes.") {
          @is_private = true
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

        parser.on("-m AMOUNT", "--amount=AMOUNT", "the amount of sending tokens") { |amount|
          @amount = amount.to_i64
        } if is_active?(actives, Options::AMOUNT)

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

        parser.on("-h", "--header", "get headers only when get a blockchain or blocks") {
          @header = true
        } if is_active?(actives, Options::HEADER)

        parser.on("--threads=THREADS", "# of the work threads (default is 1)") { |threads|
          @threads = threads.to_i
        } if is_active?(actives, Options::THREADS)

        parser.on("-e", "--encrypted", "set this flag when creating a wallet to create an encrypted wallet") {
          @encrypted = true
        } if is_active?(actives, Options::ENCRYPTED)
      end
    end

    def is_active?(actives : Array(Int32), option : Int32) : Bool
      actives.includes?(option)
    end
  end
end
