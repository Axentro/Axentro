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

require "./../../spec_helper"

include Axentro::Core
include Axentro::Core::Keys

describe Keys do
  describe "#KeyRing.generate" do
    it "should generate a private and public key pair as Key objects" do
      keys = KeyRing.generate

      keys.private_key.should be_a(PrivateKey)
      keys.private_key.as_hex.size.should eq(64)

      keys.public_key.should be_a(PublicKey)
      keys.public_key.as_hex.size.should eq(64)
    end

    it "should generate a key pair for the mainnet when no network supplied" do
      keys = KeyRing.generate
      keys.public_key.network.should eq(MAINNET)
    end

    it "should generate a key pair for the specified network" do
      keys = KeyRing.generate(TESTNET)
      keys.public_key.network.should eq(TESTNET)
    end

    it "should make a wif for mainnet when no network supplied" do
      keys = KeyRing.generate
      keys.wif.network.should eq(MAINNET)
    end

    it "should make a wif for the specified network" do
      keys = KeyRing.generate(TESTNET)
      keys.wif.network.should eq(TESTNET)
    end

    it "should make an address for mainnet when no network supplied" do
      keys = KeyRing.generate
      keys.address.network.should eq(MAINNET)
    end

    it "should make an address for the specified network" do
      keys = KeyRing.generate(TESTNET)
      keys.address.network.should eq(TESTNET)
    end
  end

  describe "#KeyRing.generate_hd" do
    it "should generate a random seed master keypair when no derivation and no seed supplied" do
      keys = KeyRing.generate_hd

      keys.private_key.should be_a(PrivateKey)
      keys.private_key.as_hex.size.should eq(64)

      keys.public_key.should be_a(PublicKey)
      keys.public_key.as_hex.size.should eq(64)

      keys.public_key.network.should eq(MAINNET)
      keys.wif.network.should eq(MAINNET)
      keys.address.network.should eq(MAINNET)

      keys.seed.should_not be_nil
    end

    it "should generate a master keypair based on the supplied seed" do
      seed = "000102030405060708090a0b0c0d0e0f"
      keys = KeyRing.generate_hd(seed)

      keys.private_key.as_hex.should eq("2b4be7f19ee27bbf30c667b642d5f4aa69fd169872f8fc3059c08ebae2eb19e7")
      keys.public_key.as_hex.should eq("a4b2856bfec510abab89753fac1ac0e1112364e7d250545963f135f2a33188ed")
      keys.wif.as_hex.should eq("TTAyYjRiZTdmMTllZTI3YmJmMzBjNjY3YjY0MmQ1ZjRhYTY5ZmQxNjk4NzJmOGZjMzA1OWMwOGViYWUyZWIxOWU3Nzg4ZTA3")

      keys.seed.should_not be_nil
    end

    it "should generate a child keypair based on the supplied seed" do
      seed = "000102030405060708090a0b0c0d0e0f"
      keys = KeyRing.generate_hd(seed, "m/0'")

      keys.private_key.as_hex.should eq("433acfc3055954411068990af648eb8a24b85b40b76db87661592e4fda13fdc7")
      keys.public_key.as_hex.should eq("883c44f8eb19e5ca570ab371c2cc6212b8099cb25c5fb0f66a3645a06069b836")
      keys.wif.as_hex.should eq("TTA0MzNhY2ZjMzA1NTk1NDQxMTA2ODk5MGFmNjQ4ZWI4YTI0Yjg1YjQwYjc2ZGI4NzY2MTU5MmU0ZmRhMTNmZGM3MWU0MGVi")

      keys.seed.should_not be_nil
    end

    it "should generate a child keypair based on a random seed" do
      keys = KeyRing.generate_hd(nil, "m/0'")

      keys.private_key.should be_a(PrivateKey)
      keys.private_key.as_hex.size.should eq(64)

      keys.public_key.should be_a(PublicKey)
      keys.public_key.as_hex.size.should eq(64)

      keys.seed.should_not be_nil
    end
  end

  describe "#KeyRing.is_valid?" do
    it "should return true when valid" do
      keys = KeyRing.generate(TESTNET)
      KeyRing.is_valid?(keys.public_key.as_hex, keys.wif.as_hex, keys.address.as_hex).should be_true
    end

    it "should raise an error when network is different between address and wif " do
      keys = KeyRing.generate(TESTNET)
      public_key = "fbc573b1fbb55088560ee58499ef1be2c6e9c532dd03aaaf46a0207f47310f91926545b8a73d60b29f626a71d1c8691fe8135fc9c63321b70fcfa8461e4a18fe"
      address = "TTBkYzFlNzgxMDRkMzBiNDJmZWI1MDlmMjg2OWY2ZmFlMDU0NTg4ZjAwYmI0MTBi"

      expect_raises(Exception, "network mismatch between address and wif") do
        KeyRing.is_valid?(public_key, keys.wif.as_hex, address)
      end
    end

    it "should raise an error when the wif's public key is different to the public key" do
      keys = KeyRing.generate(MAINNET)
      wif = "TTAzMjRkYjJmMjhjYWM0YzhhNjI2MzI3MzhmYjcwNjA2OGI3OWYxZWVhMDI5YWEzOGM5MzExNjUzMzhhYzk2OTNjMDA3ODI2"

      expect_raises(Exception, "public key mismatch between public key and wif") do
        KeyRing.is_valid?(keys.public_key.as_hex, wif, keys.address.as_hex)
      end
    end
  end
end
