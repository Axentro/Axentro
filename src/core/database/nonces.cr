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
require "../blockchain/*"
require "../blockchain/block/*"
require "../node/*"
require "../dapps/dapp"
require "../dapps/build_in/nonce_info"

module ::Axentro::Core::Data::Nonces
  # ------- Definition -------
  def nonces_table_create_string
    "address text, nonce text, latest_hash text, block_id integer, difficulty integer, timestamp integer"
  end

  def nonces_primary_key_string
    "address, nonce, block_id"
  end

  # ------- Insert -------
  def insert_nonce(nonce : Nonce)
    @db.exec("insert or ignore into nonces values (?, ?, ?, ?, ?, ?)", nonce.address, nonce.nonce, nonce.latest_hash, nonce.block_id, nonce.difficulty, nonce.timestamp)
  end

  # ------- Query -------
  def find_nonces_by_address_and_block_id(address : String, block_id : Int64) : Array(Nonce)
    nonces = [] of Nonce
    @db.query("select * from nonces where address = ? and block_id = ?", address, block_id) do |rows|
      rows.each do
        address = rows.read(String)
        nonce = rows.read(String)
        latest_hash = rows.read(String)
        block_id = rows.read(Int64)
        difficulty = rows.read(Int32)
        timestamp = rows.read(Int64)
        nonces << Nonce.new(address, nonce, latest_hash, block_id, difficulty, timestamp)
      end
    end
    nonces
  end

  include Axentro::Core::DApps::BuildIn
end
