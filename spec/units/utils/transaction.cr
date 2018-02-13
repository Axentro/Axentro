module ::Units::Utils::TransactionHelper
  include Sushi::Core

  def a_recipient(wallet : Wallet, amount : Int64)
    {address: wallet.address,
     amount:  amount}
  end

  def a_sender(wallet : Wallet, amount : Int64)
    {address:    wallet.address,
     public_key: wallet.public_key,
     amount:     amount}
  end

  def sign(wallet : Wallet, transaction : Transaction)
    secp256k1 = ECDSA::Secp256k1.new
    wif = Keys::Wif.new(wallet.wif)

    sign = secp256k1.sign(
      wif.private_key.as_big_i,
      transaction.to_hash,
    )

    {r: sign[0].to_s(base: 16), s: sign[1].to_s(base: 16)}
  end
end
