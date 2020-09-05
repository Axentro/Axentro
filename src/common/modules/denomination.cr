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

module ::Axentro::Common::Denomination
  SCALE_DECIMAL = 8

  def scale_i64(value : String) : Int64
    BigDecimal.new(value).scale_to(BigDecimal.new(1, SCALE_DECIMAL)).value.to_i64
  end

  def scale_i64(value : BigDecimal) : Int64
    value.scale_to(BigDecimal.new(1, SCALE_DECIMAL)).value.to_i64
  end

  def scale_decimal(value : Int64) : String
    BigDecimal.new(value, SCALE_DECIMAL).to_s
  end
end
