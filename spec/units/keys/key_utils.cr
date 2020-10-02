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

require "./../../spec_helper"

include Axentro::Core
include Axentro::Core::Keys

describe KeyUtils do
  it "should sign and verify" do
    hex_private_key = "56a647e7c817b5cbee64bc2f7a371415441dd1503f004ef12c50f0a6f17093e9"
    hex_public_key = "fd94245aeddf19464ffa1b667dea401ed0952ec5a9b4dbf9d652e81c67336c4f"

    message = sha256("axentro")
    signature_hex = KeyUtils.sign(hex_private_key, message)

    KeyUtils.verify_signature(message, signature_hex, hex_public_key).should be_true
  end

  it "should verify signature made in javascript (elliptic eddsa)" do
    hex_public_key = "fd94245aeddf19464ffa1b667dea401ed0952ec5a9b4dbf9d652e81c67336c4f"
    signature_hex = "442F42E88B483EBD8E3F2897918A013A3B6370906F67311FBEF6B120DAD835CDF4064CDC8EE15E87E86998BF0CBADD653CADBBC6D1F0A5856FF0230A3D437008".downcase
    message = sha256("axentro")

    KeyUtils.verify_signature(message, signature_hex, hex_public_key).should be_true
  end
end
