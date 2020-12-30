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
  class MinerNoncePool
    LIMIT = 8000000

    @@instance : MinerNoncePool? = nil

    @pool : MinerNonces = MinerNonces.new
    @pool_locked : MinerNonces = MinerNonces.new

    @locked : Bool = false

    alias MinerNoncePoolWork = NamedTuple(call: Int32, content: String)

    def self.instance : MinerNoncePool
      @@instance.not_nil!
    end

    def self.setup
      @@instance ||= MinerNoncePool.new
    end

    def self.add(miner_nonce : MinerNonce)
      instance.add(miner_nonce)
    end

    def add(miner_nonce : MinerNonce)
      if @locked
        @pool_locked << miner_nonce
      else
        insert(miner_nonce)
      end
    end

    def insert(miner_nonce : MinerNonce)
      @pool.insert(@pool.size, miner_nonce)
    end

    def self.clear_all
      instance.clear_all
    end

    def clear_all
      @pool.clear
      @pool_locked.clear
    end

    def self.delete(miner_nonce : MinerNonce)
      instance.delete(miner_nonce)
    end

    def delete(miner_nonce : MinerNonce)
      @pool.reject! { |mn| mn.id == miner_nonce.id }
    end

    def self.delete_embedded
      instance.delete_embedded
    end

    def delete_embedded
      @pool.reject! { |mn| embedded.includes?(mn) }
    end

    def self.replace(miner_nonces : MinerNonces)
      instance.replace(miner_nonces)
    end

    def replace(miner_nonces : MinerNonces)
      @pool.clear

      miner_nonces.each do |mn|
        insert(mn)
      end

      @pool_locked.each do |mn|
        insert(mn)
      end

      @locked = false

      @pool_locked.clear
    end

    def self.all
      instance.all
    end

    def all
      @pool
    end

    def self.embedded
      instance.embedded
    end

    def embedded
      @pool[0..LIMIT - 1]
    end

    def self.lock
      instance.lock
    end

    def lock
      @locked = true
    end

    def find_by_mid(mid : String) : MinerNonces
      @pool.select { |mn| mn.mid == mid }
    end

    def self.find_by_mid(mid : String) : MinerNonces
      instance.find_by_mid(mid)
    end

    def find_by_address(address : String) : MinerNonces
      @pool.select { |mn| mn.address == address }
    end

    def self.find_by_address(address : String) : MinerNonces
      instance.find_by_address(address)
    end

    def self.find(miner_nonce : MinerNonce)
      instance.find(miner_nonce)
    end

    def find(miner_nonce : MinerNonce) : MinerNonce?
      return nil unless @pool.find { |mn| mn == miner_nonce }
    end

    include Logger
    include NonceModels
  end
end
