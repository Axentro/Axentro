module ::Units::Utils::TransactionHelper
  include Sushi::Core

  def a_recipient(wallet : Wallet, amount : Int64)
    {address: wallet.address,
     amount:  amount}
  end

  def a_sender(wallet : Wallet, amount : Int64)
    {address: wallet.address,
     px:      wallet.public_key_x,
     py:      wallet.public_key_y,
     amount:  amount}
  end

  def sign(wallet : Wallet, transaction : Transaction)
    secp256k1 = ECDSA::Secp256k1.new

    sign = secp256k1.sign(
      BigInt.new(Base64.decode_string(wallet.secret_key), base: 10),
      transaction.to_hash,
    )

    {r: sign[0].to_s(base: 16), s: sign[1].to_s(base: 16)}
  end
end
