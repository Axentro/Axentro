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

module ::Axentro::Core
  CORE_VERSION = "3.0.0"
end

require "big"
require "json"
require "yaml"
require "base64"
require "router"
require "random"
require "openssl"
require "colorize"
require "tokoroten"
require "http/server"
require "openssl/pkcs5"
require "openssl/digest"
require "humanhash"
require "crystal-argon2"
require "monocypher"
require "ed25519-hd"
require "i18n"
require "baked_file_system"
require "tallboy"
require "defense"
require "crest"
require "rate_limiter"
require "crometheus"
require "mg"
require "msgpack"
require "lru-cache"

require "./common"
require "./core/modules"
require "./core/protocol"
require "./core/key_ring"
require "./core/*"
