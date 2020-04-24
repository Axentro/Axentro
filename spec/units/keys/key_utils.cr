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

require "./../../spec_helper"

include Sushi::Core
include Sushi::Core::Keys

describe KeyUtils do
  it "should sign and verify" do
    hex_private_key = "56a647e7c817b5cbee64bc2f7a371415441dd1503f004ef12c50f0a6f17093e9"
    hex_public_key = "fd94245aeddf19464ffa1b667dea401ed0952ec5a9b4dbf9d652e81c67336c4f"

    message = sha256("sushichain")
    signature_hex = KeyUtils.sign(hex_private_key, message)

    KeyUtils.verify_signature(message, signature_hex, hex_public_key).should be_true
  end

  it "should verify signature made in javascript (elliptic eddsa)" do
    hex_public_key = "fd94245aeddf19464ffa1b667dea401ed0952ec5a9b4dbf9d652e81c67336c4f"
    signature_hex = "D1712D66C4924EA071063F6EF2A0B9555314CE723AF51749D8E2F2ACF3E95C1AC19B1B67776FF8B5C84C92DF5E7476C1DF9F3AB97384D4A511350CEF337F7B0C".downcase
    message = sha256("sushichain")

    KeyUtils.verify_signature(message, signature_hex, hex_public_key).should be_true
  end
end
