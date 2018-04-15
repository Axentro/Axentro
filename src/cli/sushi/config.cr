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
          name: "clean",
          desc: "clean the default configuration",
        },
      ]
    end

    def option_parser
      create_option_parser([
        Options::CONNECT_NODE,
        Options::WALLET_PATH,
        # Options::WALLET_PASSWORD,
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
      ])
    end

    def run_impl(action_name)
      case action_name
      when "save"
        return save
      when "show"
        return show
      when "clean"
        return clean
      end

      specify_sub_action!(action_name)
    rescue e : Exception
      puts_error e.message
    end

    def save
      cm.set("connect_node", __connect_node)
      cm.set("wallet_path", __wallet_path)
      cm.set("is_testnet", __is_testnet)
      cm.set("is_private", __is_private)
      cm.set("bind_host", __bind_host)
      cm.set("bind_port", __bind_port)
      cm.set("public_url", __public_url)
      cm.set("database_path", __database_path)
      cm.set("threads", __threads)
      cm.set("encrypted", __encrypted)
      cm.save

      puts_success "saved the configuration at #{cm.config_path}"

      cm.release_config

      if config = cm.get_config
        puts_info config.to_s
      end
    end

    def show
      if config = cm.get_config
        puts_success "show current configuration at #{cm.config_path}"
        puts_info config.to_s
      else
        puts_error "no configuration found at #{cm.config_path}"
        puts_error "to create a configuration, exec `sushi config save [your_options]`"
      end
    end

    def clean
      puts_success "delete configuration at #{cm.config_path}"
      cm.clean
    end

    include GlobalOptionParser
  end
end
