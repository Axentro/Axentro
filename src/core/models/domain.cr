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

module ::Sushi::Core::Models
  module DomainStatus
    Acquired =  0
    ForSale  =  1
    NotFound = -1
  end

  alias Domain = NamedTuple(domain_name: String, address: String, status: Int32, price: Int64)
  alias DomainMap = Hash(String, Domain)
end
