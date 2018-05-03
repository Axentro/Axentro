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
  class ConfigManager
    alias Configurable = String | Int32 | Int64 | Bool | Nil

    @@manager = nil

    def self.get_instance : ConfigManager
      @@manager ||= ConfigManager.new
      @@manager.not_nil!
    end

    @config_map : Hash(String, Configurable)
    @config : Config?

    def initialize
      @config_map = Hash(String, Configurable).new
    end

    def set(name : String, value : Configurable)
      return if value.is_a?(Nil)
      @config_map[name] = value
    end

    def get_config : Hash(String, Configurable)?
      return nil unless File.exists?(config_path)
      @config ||= Config.from_yaml(File.read(config_path))
      return nil if @config.nil?
      # raise "configuration is currently disabled - exec `sushi config enable` to enable it" if @config.not_nil!.config_status == ConfigStatus::Disabled
      @config.not_nil!.configs[@config.not_nil!.current_config]
    end

    def get_configs : Hash(String, Hash(String, ConfigManager::Configurable))
      raise "no configuration file found at: #{config_path} - to create, exec `sushi config save [your_options]" unless File.exists?(config_path)
      config = Config.from_yaml(File.read(config_path))
      config.configs
    end

    def set_enabled_state(state : ConfigStatus)
      config = Config.from_yaml(File.read(config_path))
      config.config_status = state
      File.write(config_path, config.to_yaml)
    end

    def config
      @config.not_nil!
    end

    def release_config
      @config = nil
    end

    def get_s(name : String) : String?
      return nil unless config = get_config
      return nil unless config[name]?

      config[name].to_s
    end

    def get_i32(name : String) : Int32?
      return nil unless config = get_config
      return nil unless config[name]?

      config[name].to_s.to_i32
    end

    def get_i64(name : String) : Int64?
      return nil unless config = get_config
      return nil unless config[name]?

      config[name].to_i64
    end

    def get_bool(name : String) : Bool?
      return nil unless config = get_config
      return nil unless config[name]?

      config[name].to_s == "true"
    end

    def save(name : String?, update_name_only : Bool = false)
      config_name = name ? name : "config"
      config = File.exists?(config_path) ? Config.from_yaml(File.read(config_path)) : Config.new(config_name, ConfigStatus::Enabled, {config_name => @config_map})
      config.current_config = config_name
      config.configs[config_name] = @config_map unless update_name_only
      File.write(config_path, config.to_yaml)
    end

    def remove_all
      FileUtils.rm_rf(config_path)
    end

    def remove_config(name : String)
      config = Config.from_yaml(File.read(config_path))
      config.configs.delete(name)
      File.write(config_path, config.to_yaml)
    end

    def config_path : String
      home = File.expand_path("~")
      FileUtils.mkdir_p("#{home}/.sushi")
      "#{home}/.sushi/config"
    end
  end
end

enum ConfigStatus
  Enabled
  Disabled
end

class Config
  YAML.mapping(current_config: String, config_status: ConfigStatus, configs: Hash(String, Hash(String, ConfigManager::Configurable)))

  def initialize(@current_config : String, @config_status : ConfigStatus, @configs : Hash(String, Hash(String, ConfigManager::Configurable)))
  end
end
