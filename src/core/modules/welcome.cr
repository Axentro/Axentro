# Copyright © 2017-2018 The Axentro Core developers
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
.d8888. db    db .d8888. db   db d888888b  .o88b. db   db  .d8b.  d888888b d8b   db
88'  YP 88    88 88'  YP 88   88   `88'   d8P  Y8 88   88 d8' `8b   `88'   888o  88
`8bo.   88    88 `8bo.   88ooo88    88    8P      88ooo88 88ooo88    88    88V8o 88
  `Y8b. 88    88   `Y8b. 88~~~88    88    8b      88~~~88 88~~~88    88    88 V8o88
db   8D 88b  d88 db   8D 88   88   .88.   Y8b  d8 88   88 88   88   .88.   88  V888
`8888Y' ~Y8888P' `8888Y' YP   YP Y888888P  `Y88P' YP   YP YP   YP Y888888P VP   V8P
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
