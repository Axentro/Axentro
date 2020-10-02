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

module ::Axentro::Interface::Axe
  class Config < CLI
    def sub_actions
      [
        {
          name: I18n.translate("axe.cli.config.save.title"),
          desc: I18n.translate("axe.cli.config.save.desc"),
        },
        {
          name: I18n.translate("axe.cli.config.show.title"),
          desc: I18n.translate("axe.cli.config.show.desc"),
        },
        {
          name: I18n.translate("axe.cli.config.remove.title"),
          desc: I18n.translate("axe.cli.config.remove.desc"),
        },
        {
          name: I18n.translate("axe.cli.config.use.title"),
          desc: I18n.translate("axe.cli.config.use.desc"),
        },
        {
          name: I18n.translate("axe.cli.config.list.title"),
          desc: I18n.translate("axe.cli.config.list.desc"),
        },
        {
          name: I18n.translate("axe.cli.config.enable.title"),
          desc: I18n.translate("axe.cli.config.enable.desc"),
        },
        {
          name: I18n.translate("axe.cli.config.disable.title"),
          desc: I18n.translate("axe.cli.config.disable.desc"),
        },
      ]
    end

    def option_parser
      G.op.create_option_parser([
        Options::CONNECT_NODE,
        Options::WALLET_PATH,
        Options::WALLET_PASSWORD,
        Options::IS_TESTNET,
        Options::IS_PRIVATE,
        # Options::JSON,
        Options::BIND_HOST,
        Options::BIND_PORT,
        Options::PUBLIC_URL,
        Options::DATABASE_PATH,
        Options::ADDRESS,
        Options::DOMAIN,
        # Options::AMOUNT,
        # Options::MESSAGE,
        # Options::BLOCK_INDEX,
        # Options::TRANSACTION_ID,
        # Options::HEADER,
        Options::PROCESSES,
        Options::ENCRYPTED,
        Options::CONFIG_NAME,
      ])
    end

    def run_impl(action_name)
      case action_name
      when I18n.translate("axe.cli.config.save.title")
        return save
      when I18n.translate("axe.cli.config.show.title")
        return show
      when I18n.translate("axe.cli.config.remove.title")
        return remove
      when I18n.translate("axe.cli.config.use.title")
        return use
      when I18n.translate("axe.cli.config.list.title")
        return list
      when I18n.translate("axe.cli.config.disable.title")
        return enabled(ConfigStatus::Disabled)
      when I18n.translate("axe.cli.config.enable.title")
        return enabled(ConfigStatus::Enabled)
      end

      specify_sub_action!(action_name)
    rescue e : Exception
      puts_error e.message
    end

    def cm
      G.op.cm
    end

    def save
      cm.set_enabled_state(ConfigStatus::Disabled)
      cm.set_override_state(false)
      cm.set("connect_node", G.op.__connect_node)
      cm.set("wallet_path", absolute_path(G.op.__wallet_path))
      cm.set("is_testnet", G.op.__is_testnet)
      cm.set("is_private", G.op.__is_private)
      cm.set("bind_host", G.op.__bind_host)
      cm.set("bind_port", G.op.__bind_port)
      cm.set("public_url", G.op.__public_url)
      cm.set("database_path", G.op.__database_path)
      cm.set("processes", G.op.__processes)
      cm.set("encrypted", G.op.__encrypted)
      cm.set("wallet_password", G.op.__wallet_password)
      cm.set("address", G.op.__address)
      cm.set("domain", G.op.__domain)
      cm.save(G.op.__name)
      cm.set_enabled_state(ConfigStatus::Enabled)
      cm.set_override_state(true)
      puts_success "saved the configuration at #{cm.config_path}"

      cm.release_config
      show_config
    end

    def show
      with_config do |configs, current_config|
        if G.op.__name.nil?
          puts_success "current configuration is for: '#{current_config.name}' in file #{cm.config_path}"
          puts_info current_config.to_s
        else
          with_name(G.op.__name, configs) do |config, name|
            puts_success "showing configuration for: '#{name}' in file #{cm.config_path}"
            puts_info ConfigItem.new(name, current_config.status, config).to_s
          end
        end
      end
    end

    def remove
      with_config do |configs, current_config|
        G.op.__name.nil? ? remove_all : with_name(G.op.__name, configs) { |_, name| configs.keys.size > 1 ? remove_config(name, current_config.name) : remove_all }
      end
    end

    def use
      puts_help(HELP_CONFIG_NAME) unless name = G.op.__name
      with_config do |configs, _|
        with_name(name, configs) do
          cm.save(name, true)
          puts_success "using configuration '#{name}' at #{cm.config_path}"
          show_config
        end
      end
    end

    def list
      with_config do |configs, current_config|
        puts_info "configuration is #{current_config.status}"
        if configs.keys.empty?
          puts_error "there are no configurations yet " +
                     "- to create, exec `axe config save [your_options]`"
        else
          puts_success "the following configs exist at #{cm.config_path}"
          configs.keys.each { |config| puts_info config }
        end
      end
    end

    def enabled(status : ConfigStatus)
      with_config do |_, _|
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
        raise "no configuration file found at: #{cm.config_path} - to create, exec `axe config save [your_options]"
      end
      yield configs, current_config
    end

    private def remove_all
      puts_success "removed all configurations at #{cm.config_path}"
      cm.remove_all
    end

    private def remove_config(name, current_config)
      raise "sorry you cannot remove a config you are currently using" if name == current_config
      puts_success "removed configuration for: '#{name}' in file #{cm.config_path}"
      cm.remove_config(name)
    end

    private def show_config
      if config = cm.get_config
        puts_info config.to_s
      end
    end
  end
end
