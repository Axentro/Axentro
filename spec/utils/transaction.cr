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

module ::Units::Utils::TransactionHelper
  include Axentro::Core

  def a_recipient(wallet : Wallet, amount : Int64) : Transaction::Recipient
    Recipient.new(wallet.address, amount)
  end

  def a_recipient(recipient_address : String, amount : Int64) : Transaction::Recipient
    Recipient.new(recipient_address, amount)
  end

  def a_sender(wallet : Wallet, amount : Int64, fee : Int64 = 10000_i64) : Transaction::Sender
    Sender.new(wallet.address, wallet.public_key, amount, fee, "0")
  end

  def a_sender(sender_address : String, sender_public_key : String, amount : Int64, fee : Int64 = 10000_i64) : Transaction::Sender
    Sender.new(sender_address, sender_public_key, amount, fee, "0")
  end

  def a_signed_sender(wallet : Wallet, amount : Int64, signature : String, fee : Int64 = 10000_i64) : Transaction::Sender
    Sender.new(wallet.address, wallet.public_key, amount, fee, "0")
  end

  def a_decimal_recipient(wallet : Wallet, amount : String) : Transaction::RecipientDecimal
    {address: wallet.address,
     amount:  amount}
  end

  def a_decimal_sender(wallet : Wallet, amount : String, fee : String = "0.0001") : Transaction::SenderDecimal
    {address:    wallet.address,
     public_key: wallet.public_key,
     amount:     amount,
     fee:        fee,
     signature:  "0",
    }
  end

  # def sign(wallet : Wallet, transaction : Transaction)
  #   secp256k1 = ECDSA::Secp256k1.new
  #   wif = Keys::Wif.new(wallet.wif)

  #   sign = secp256k1.sign(
  #     wif.private_key.as_big_i,
  #     transaction.to_hash,
  #   )

  #   {r: sign[0].to_s(base: 16), s: sign[1].to_s(base: 16)}
  # end
end
