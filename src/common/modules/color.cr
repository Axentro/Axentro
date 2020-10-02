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

module ::Axentro::Common::Color
  COLORS = %w(black red green yellow blue magenta cyan light_gray dark_gray light_red light_green light_yellow light_blue light_magenta light_cyan white)

  {% for color in COLORS %}
    def {{color.id}}(s) : String
      s.to_s.colorize.fore(:{{color.id}}).to_s
    end

    def {{color.id}}_bg(s) : String
      s.to_s.colorize.back(:{{color.id}}).to_s
    end
  {% end %}
end
