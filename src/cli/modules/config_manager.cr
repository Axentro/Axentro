module ::Sushi::Interface
  class ConfigManager

    alias Configurable = String|Int32|Int64|Bool|Nil

    @@manager = nil

    def self.get_instance : ConfigManager
      @@manager ||= ConfigManager.new
      @@manager.not_nil!
    end

    @config_map : Hash(String, Configurable)
    @config_yaml : YAML::Any?

    def initialize
      @config_map = Hash(String, Configurable).new
    end

    def set(name : String, value : Configurable)
      return if value.is_a?(Nil)
      @config_map[name] = value
    end

    def get_config : YAML::Any
      @config_yaml ||= YAML.parse(File.read(config_path))
      @config_yaml.not_nil!
    end

    def get_s(name : String) : String
      get_config[name].as_s
    end

    def get_i32(name : String) : Int32
      get_config[name].as_i
    end

    def get_i64(name : String) : Int64
      get_config[name].as_i64
    end

    def get_bool(name : String) : Bool
      get_config[name].to_s == "true"
    end

    def save
      File.write(config_path, YAML.dump(@config_map))
    end

    def clean
      FileUtils.rm_rf(config_path)
    end

    def config_path : String
      home = File.expand_path("~")

      FileUtils.mkdir_p("#{home}/.sushi")

      "#{home}/.sushi/config"
    end
  end
end
