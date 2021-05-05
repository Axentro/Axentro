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
require "yaml"

module ::Axentro::Interface
  class ConfigManager
    alias Configurable = String | Int32 | Int64 | Bool | Nil

    @@manager = nil

    def self.get_instance : ConfigManager
      @@manager ||= ConfigManager.new
      @@manager.not_nil!
    end

    @config_map : Hash(String, Configurable)
    @config : Config?
    @override : Bool = true

    def initialize
      @config_map = Hash(String, Configurable).new
    end

    def set(name : String, value : Configurable)
      return if value.nil?
      @config_map[name] = value
    end

    def get_config(override_name : String | Nil = nil) : ConfigItem?
      return nil unless File.exists?(config_path)
      @config = Config.from_yaml(File.read(config_path))
      if config = @config
        current_config = (@override && !override_name.nil?) ? config.configs[override_name] : config.configs[config.current_config]
        ConfigItem.new(config.current_config, config.config_status, current_config)
      end
    end

    def get_configs : Hash(String, Hash(String, ConfigManager::Configurable))
      raise "no configuration file found at: #{config_path} - to create, exec `axe config save [your_options]" unless File.exists?(config_path)
      config = Config.from_yaml(File.read(config_path))
      config.configs
    end

    def release_config
      @config = nil
    end

    def set_override_state(value : Bool)
      @override = value
    end

    private def with_config_for(name, override_name, &block)
      return nil unless config_item = get_config(override_name)
      return nil unless config = config_item.config
      return nil unless config[name]?
      return nil unless config_item.is_enabled?

      yield config[name]
    end

    def get_s(name : String, config : String | Nil) : String?
      with_config_for(name, config) do |config_name|
        config_name.to_s
      end
    end

    def get_i32(name : String, config : String | Nil) : Int32?
      with_config_for(name, config) do |config_name|
        config_name.to_s.to_i32
      end
    end

    def get_i64(name : String, config : String | Nil) : Int64?
      with_config_for(name, config) do |config_name|
        config_name.to_i64
      end
    end

    def get_bool(name : String, config : String | Nil) : Bool?
      with_config_for(name, config) do |config_name|
        config_name.to_s == "true"
      end
    end

    def save(name : String?, update_name_only : Bool = false)
      config_name = name ? name : "config"
      config = Config.from_yaml(File.read(config_path))
      config.current_config = config_name
      config.configs[config_name] = @config_map unless update_name_only
      File.write(config_path, config.to_yaml)
    end

    def set_enabled_state(state : ConfigStatus)
      config = File.exists?(config_path) ? Config.from_yaml(File.read(config_path)) : Config.new("config", state, {"config" => @config_map})
      config.config_status = state
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
      home = Path.home.to_s
      FileUtils.mkdir_p("#{home}/.axentro")
      "#{home}/.axentro/config"
    end
  end
end

enum ConfigStatus
  Enabled
  Disabled
end

struct ConfigItem
  property name : String
  property status : ConfigStatus
  property config : Hash(String, ConfigManager::Configurable)

  def initialize(@name : String, @status : ConfigStatus, @config : Hash(String, ConfigManager::Configurable))
  end

  def is_enabled?
    @status == ConfigStatus::Enabled
  end

  def to_s
    details = @config.join("\n") { |k, v| "#{k}:\t#{v}" }
    "configuration is #{@status} \n--------------------\n#{details}"
  end
end

class Config
  include YAML::Serializable

  property current_config : String
  property configs : Hash(String, Hash(String, ConfigManager::Configurable))
  property config_status : ConfigStatus

  def initialize(@current_config, @config_status, @configs)
  end
end
