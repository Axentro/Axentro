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

module ::Units::Utils::TransactionHelper
  include Sushi::Core

  def a_recipient(wallet : Wallet, amount : Int64) : Recipient
    {address: wallet.address,
     amount:  amount}
  end

  def a_sender(wallet : Wallet, amount : Int64, fee : Int64 = 1_i64) : Sender
    {address:    wallet.address,
     public_key: wallet.public_key,
     amount:     amount,
     fee:        fee,
    }
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

  def transactions_for_the_address : String
    %([{"id":"f2a4a3723fe054b91e560f1a1450812018d31f3a3e2fb3c8c765680e31df5ee4","action":"head","senders":[],"recipients":[{"address":"TTBjOGYyMDJjZjVmNjg0YzhmNTBlNTRmNGQ3ZjFiZDRkNzE4NTkzODM2NDlmODZi","amount":10000}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"},{"id":"7d925a249d161d895be689d8369c718e0800f8d735fc0fc46dfb09c4862de9e7","action":"head","senders":[],"recipients":[{"address":"TTBjOGYyMDJjZjVmNjg0YzhmNTBlNTRmNGQ3ZjFiZDRkNzE4NTkzODM2NDlmODZi","amount":2500},{"address":"TTA4NjNiMjIzNjMwYjViOGVmMmYwZjU0YTFkNTE5YmQ2MWIyYmFiOGIyODVlNTk5","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"},{"id":"1d0219500820a9be161c4ce1e1c2754c8811526e4bc26bf06a1c69b03dd17beb","action":"head","senders":[],"recipients":[{"address":"TTBjOGYyMDJjZjVmNjg0YzhmNTBlNTRmNGQ3ZjFiZDRkNzE4NTkzODM2NDlmODZi","amount":2500},{"address":"TTA4NjNiMjIzNjMwYjViOGVmMmYwZjU0YTFkNTE5YmQ2MWIyYmFiOGIyODVlNTk5","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"},{"id":"c7aeb946302384e4cb83365b73e47150f5c7c8ce93935a085f8dd785e84073f3","action":"head","senders":[],"recipients":[{"address":"TTBjOGYyMDJjZjVmNjg0YzhmNTBlNTRmNGQ3ZjFiZDRkNzE4NTkzODM2NDlmODZi","amount":2500},{"address":"TTA4NjNiMjIzNjMwYjViOGVmMmYwZjU0YTFkNTE5YmQ2MWIyYmFiOGIyODVlNTk5","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"},{"id":"1c4c5699d3837dfb406c054acc5644266befa4ab72a937ea9eaa7c4c4edb2ece","action":"head","senders":[],"recipients":[{"address":"TTBjOGYyMDJjZjVmNjg0YzhmNTBlNTRmNGQ3ZjFiZDRkNzE4NTkzODM2NDlmODZi","amount":2500},{"address":"TTA4NjNiMjIzNjMwYjViOGVmMmYwZjU0YTFkNTE5YmQ2MWIyYmFiOGIyODVlNTk5","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"},{"id":"1e65a6bc52ea9a979cbb8782b19d7a57cbe70cefe1b95ba90fbd493ca51f7a85","action":"head","senders":[],"recipients":[{"address":"TTBjOGYyMDJjZjVmNjg0YzhmNTBlNTRmNGQ3ZjFiZDRkNzE4NTkzODM2NDlmODZi","amount":2500},{"address":"TTA4NjNiMjIzNjMwYjViOGVmMmYwZjU0YTFkNTE5YmQ2MWIyYmFiOGIyODVlNTk5","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"},{"id":"65cb19d1b4a1dc800e309c4209a1ff1a0e640441061df0310cacd94dffa560d3","action":"head","senders":[],"recipients":[{"address":"TTBjOGYyMDJjZjVmNjg0YzhmNTBlNTRmNGQ3ZjFiZDRkNzE4NTkzODM2NDlmODZi","amount":2500},{"address":"TTA4NjNiMjIzNjMwYjViOGVmMmYwZjU0YTFkNTE5YmQ2MWIyYmFiOGIyODVlNTk5","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"},{"id":"5c244b1f7a75b9421a3d120446b819432f0c73997f0ecbb10adc2749f0d95443","action":"head","senders":[],"recipients":[{"address":"TTBjOGYyMDJjZjVmNjg0YzhmNTBlNTRmNGQ3ZjFiZDRkNzE4NTkzODM2NDlmODZi","amount":2500},{"address":"TTA4NjNiMjIzNjMwYjViOGVmMmYwZjU0YTFkNTE5YmQ2MWIyYmFiOGIyODVlNTk5","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"},{"id":"66db8c31cb20eedadbe825305fc542dbc113082f7e7e49a2f0d7001c147f656b","action":"head","senders":[],"recipients":[{"address":"TTBjOGYyMDJjZjVmNjg0YzhmNTBlNTRmNGQ3ZjFiZDRkNzE4NTkzODM2NDlmODZi","amount":2500},{"address":"TTA4NjNiMjIzNjMwYjViOGVmMmYwZjU0YTFkNTE5YmQ2MWIyYmFiOGIyODVlNTk5","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"},{"id":"8fc33ce4ca8e0953312a31085823c535014484541d2414b2c9da08deccdaa45f","action":"head","senders":[],"recipients":[{"address":"TTBjOGYyMDJjZjVmNjg0YzhmNTBlNTRmNGQ3ZjFiZDRkNzE4NTkzODM2NDlmODZi","amount":2500},{"address":"TTA4NjNiMjIzNjMwYjViOGVmMmYwZjU0YTFkNTE5YmQ2MWIyYmFiOGIyODVlNTk5","amount":7500}],"message":"0","prev_hash":"0","sign_r":"0","sign_s":"0"}])
  end
end
