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

module ::Sushi::Core
  CORE_VERSION = 1
end

require "big"
require "json"
require "base64"
require "router"
require "random"
require "scrypt"
require "openssl"
require "colorize"
require "tokoroten"
require "http/server"
require "openssl/pkcs5"
require "openssl/digest"

require "./common"
require "./core/modules"
require "./core/protocol"
require "./core/keys"
require "./core/*"

#
# todo:
# 1. checking signing of transaction when receive it.
# 2. align without checking signing
# 3. nonce will not be fixed with 0.
# 4. integrate valid_with(out)_dapps again.
#
