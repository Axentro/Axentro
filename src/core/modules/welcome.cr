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

module ::Axentro::Core::Welcome
  def logo
    plain = <<-LOGO
           d8888                            888
          d88888                            888
         d88P888                            888
        d88P 888 888  888  .d88b.  88888b.  888888 888d888 .d88b.
       d88P  888 `Y8bd8P' d8P  Y8b 888 "88b 888    888P"  d88""88b
      d88P   888   X88K   88888888 888  888 888    888    888  888
     d8888888888 .d8""8b. Y8b.     888  888 Y88b.  888    Y88..88P
    d88P     888 888  888  "Y8888  888  888  "Y888 888     "Y88P"
    LOGO

    light_green(plain)
  end

  def welcome_message : String
    <<-MSG

  Welcome to

  #{logo}

  Core version: #{light_green(CORE_VERSION)}


  MSG
  end

  include Common::Color
end
