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

module ::Axentro::Core::Keys
  class PrivateKey
    getter network : Core::Node::Network

    def initialize(private_key_hex : String, @network : Core::Node::Network = MAINNET)
      @hex = private_key_hex
      raise "invalid private key: #{@hex}" unless is_valid?
    end

    def self.from(hex : String, network : Core::Node::Network = MAINNET) : PrivateKey
      PrivateKey.new(hex, network)
    end

    def self.from(bytes : Bytes, network : Core::Node::Network = MAINNET) : PrivateKey
      PrivateKey.new(KeyUtils.to_hex(bytes), network)
    end

    def as_hex : String
      @hex
    end

    def as_bytes : Bytes
      KeyUtils.to_bytes(@hex)
    end

    def as_big_i : BigInt
      @hex.to_big_i(16)
    end

    def wif : Wif
      Wif.from(self, @network)
    end

    def public_key : PublicKey
      secret_key = Crypto::SecretKey.new(self.as_hex)
      hex_public_key = Crypto::Ed25519PublicSigningKey.new(secret: secret_key).to_slice.hexstring
      PublicKey.new(hex_public_key, @network)
    end

    def address : Address
      Address.new(KeyUtils.get_address_from_public_key(self.public_key), @network)
    end

    def is_valid? : Bool
      @hex.hexbytes? != nil && @hex.size == 64
    end
  end
end
