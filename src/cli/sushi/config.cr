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

module ::Sushi::Interface::Sushi
  class Config < CLI
    def sub_actions
      [
        {
          name: "save",
          desc: "save the specified options as default for sushi, sushid and sushim",
        },
        {
          name: "show",
          desc: "show current default configuration",
        },
        {
          name: "remove",
          desc: "remove the default configuration",
        },
        {
          name: "use",
          desc: "use the specified configuration",
        },
        {
          name: "list",
          desc: "list the available configurations",
        },
        {
          name: "enable",
          desc: "enable configurations",
        },
        {
          name: "disable",
          desc: "disable configurations",
        },
      ]
    end

    def option_parser
      create_option_parser([
        Options::CONNECT_NODE,
        Options::WALLET_PATH,
        Options::WALLET_PASSWORD,
        Options::IS_TESTNET,
        Options::IS_PRIVATE,
        # Options::JSON,
        # Options::UNCONFIRMED,
        Options::BIND_HOST,
        Options::BIND_PORT,
        Options::PUBLIC_URL,
        Options::DATABASE_PATH,
        # Options::ADDRESS,
        # Options::AMOUNT,
        # Options::MESSAGE,
        # Options::BLOCK_INDEX,
        # Options::TRANSACTION_ID,
        # Options::HEADER,
        Options::THREADS,
        Options::ENCRYPTED,
        Options::CONFIG_NAME,
      ])
    end

    def run_impl(action_name)
      case action_name
      when "save"
        return save
      when "show"
        return show
      when "remove"
        return remove
      when "use"
        return use
      when "list"
        return list
      when "disable"
        return enabled(ConfigStatus::Disabled)
      when "enable"
        return enabled(ConfigStatus::Enabled)
      end

      specify_sub_action!(action_name)
    rescue e : Exception
      puts_error e.message
    end

    def save
      cm.set("connect_node", __connect_node)
      cm.set("wallet_path", absolute_path(__wallet_path))
      cm.set("is_testnet", __is_testnet)
      cm.set("is_private", __is_private)
      cm.set("bind_host", __bind_host)
      cm.set("bind_port", __bind_port)
      cm.set("public_url", __public_url)
      cm.set("database_path", __database_path)
      cm.set("threads", __threads)
      cm.set("encrypted", __encrypted)
      cm.set("wallet_password", __wallet_password)
      cm.save(__name)

      puts_success "saved the configuration at #{cm.config_path}"

      cm.release_config
      if config = cm.get_config
        puts_info config.to_s
      end
    end

    def show
      with_config do |configs, current_config|
        if __name.nil?
          puts_success "current configuration is for: '#{current_config.name}' in file #{cm.config_path}"
          puts_info current_config.to_s
        else
          with_name(__name, configs) do |config, name|
            puts_success "showing configuration for: '#{name}' in file #{cm.config_path}"
            puts_info config.to_s
          end
        end
      end
    end

    def remove
      with_config do |configs, current_config|
        if __name.nil?
          remove_all
        else
          with_name(__name, configs) do |config, name|
            if configs.keys.size > 1
              puts_success "removed configuration for: '#{name}' in file #{cm.config_path}"
              cm.remove_config(name)
            else
              remove_all
            end
          end
        end
      end
    end

    def use
      puts_help(HELP_CONFIG_NAME) unless name = __name
      with_config do |configs, current_config|
        with_name(name, configs) do
          cm.save(name, true)
          puts_success "using configuration '#{name}' at #{cm.config_path}"
          puts_info current_config.to_s
        end
      end
    end

    def list
      with_config do |configs, current_config|
        puts_info "configuration is #{current_config.status}"
        if configs.keys.empty?
          puts_error "there are no configurations yet - to create, exec `sushi config save [your_options]`"
        else
          puts_success "the following configs exist at #{cm.config_path}"
          configs.keys.each { |config| puts_info config }
        end
      end
    end

    def enabled(status : ConfigStatus)
      with_config do |configs, current_config|
        cm.set_enabled_state(status)
        puts_success "configuration has been #{status} - #{cm.config_path}"
      end
    end

    private def absolute_path(file)
      case file
      when String
        File.expand_path(file)
      else
        nil
      end
    end

    private def with_name(name, configs, &block)
      if configs.keys.includes?(name)
        yield configs[name], name.not_nil!
      else
        puts_error "no configuration found for '#{name}' at #{cm.config_path}"
      end
    end

    private def with_config(&block)
      configs = cm.get_configs
      current_config = cm.get_config
      if configs.keys.empty? || current_config.nil?
        raise "no configuration file found at: #{cm.config_path} - to create, exec `sushi config save [your_options]"
      end
      yield configs, current_config
    end

    private def remove_all
      puts_success "removed all configurations at #{cm.config_path}"
      cm.remove_all
    end

    include GlobalOptionParser
  end
end
