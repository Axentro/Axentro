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
include Units::Utils
include Axentro::Core::Controllers
include Axentro::Core::Keys

describe Node do
  it "should not process a fast block that is not signed by an official fast node" do
    with_factory do |block_factory, _|
      node = block_factory.node
      not_official_fast_node_wallet = Wallet.from_json(Wallet.create(true).to_json)
      block = create_fast_block(not_official_fast_node_wallet)
      node.fast_block_was_signed_by_official_fast_node?(block).should eq(false)
    end
  end
  it "should process a fast block when signed by an official fast node" do
    with_factory do |block_factory, _|
      node = block_factory.node
      block = create_fast_block(block_factory.node_wallet)
      node.fast_block_was_signed_by_official_fast_node?(block).should eq(true)
    end
  end
end

private def create_fast_block(wallet)
  transactions = [] of Transaction
  latest_index = 1_i64

  latest_block_hash = "b23086bd140a5919dffa98ed010ff6e81b9057d85a7be1658e81c328afb1cd69"
  timestamp = 1603350996574

  address = wallet.address
  public_key = wallet.public_key

  hash = Block.to_hash(latest_index, transactions, latest_block_hash, address, public_key)
  private_key = Wif.new(wallet.wif).private_key.as_hex
  signature = KeyUtils.sign(private_key, hash)

  Block.new(
    latest_index,
    transactions,
    latest_block_hash,
    timestamp,
    address,
    public_key,
    signature,
    hash,
    BlockVersion::V2,
    HashVersion::V2,
    ""
  )
end
