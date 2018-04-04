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

module ::Units::Utils::BlockHelper
  include Sushi::Core

  def genesis_block
    json = %{
      {
        "index": 0,
       "transactions": [],
       "nonce": 0,
       "prev_hash": "genesis",
       "merkle_tree_root": ""
      }
    }
    Block.from_json(json)
  end

  def block_1
    json = %{
      {
    "index": 1,
    "transactions": [
      {
        "id": "f2a4a3723fe054b91e560f1a1450812018d31f3a3e2fb3c8c765680e31df5ee4",
        "action": "head",
        "senders": [],
        "recipients": [
          {
            "address": "TTBjOGYyMDJjZjVmNjg0YzhmNTBlNTRmNGQ3ZjFiZDRkNzE4NTkzODM2NDlmODZi",
            "amount": 10000
          }
        ],
        "message": "0",
        "token": "#{TOKEN_DEFAULT}",
        "prev_hash": "0",
        "sign_r": "0",
        "sign_s": "0"
      }
    ],
    "nonce": 1103761249925206526,
    "prev_hash": "5396e18efa80a8e891c417fff862d7cad171465e65bc4b4e5e1c1c3ab0aeb88f",
    "merkle_tree_root": "60ebe5469446a0e2b60b80972ebfb8b63f971477"
  }
    }
    Block.from_json(json)
  end

  def block_2
    json = %{
      {
    "index": 2,
    "transactions": [
      {
        "id": "7d925a249d161d895be689d8369c718e0800f8d735fc0fc46dfb09c4862de9e7",
        "action": "head",
        "senders": [],
        "recipients": [
          {
            "address": "TTBjOGYyMDJjZjVmNjg0YzhmNTBlNTRmNGQ3ZjFiZDRkNzE4NTkzODM2NDlmODZi",
            "amount": 2500
          },
          {
            "address": "TTA4NjNiMjIzNjMwYjViOGVmMmYwZjU0YTFkNTE5YmQ2MWIyYmFiOGIyODVlNTk5",
            "amount": 7500
          }
        ],
        "message": "0",
        "token": "#{TOKEN_DEFAULT}",
        "prev_hash": "0",
        "sign_r": "0",
        "sign_s": "0"
      }
    ],
    "nonce": 11121314448198599040,
    "prev_hash": "a50254a09ee8b6325e2c044048dde963b8d2433817f13fbb829a9ac96c1dc68a",
    "merkle_tree_root": "3f1a5c8c4bf63354a0a4bb5915c7484d5adc2a38"
  }
    }
    Block.from_json(json)
  end

  def block_3
    json = %{
      {
    "index": 3,
    "transactions": [
      {
        "id": "1d0219500820a9be161c4ce1e1c2754c8811526e4bc26bf06a1c69b03dd17beb",
        "action": "head",
        "senders": [],
        "recipients": [
          {
            "address": "TTBjOGYyMDJjZjVmNjg0YzhmNTBlNTRmNGQ3ZjFiZDRkNzE4NTkzODM2NDlmODZi",
            "amount": 2500
          },
          {
            "address": "TTA4NjNiMjIzNjMwYjViOGVmMmYwZjU0YTFkNTE5YmQ2MWIyYmFiOGIyODVlNTk5",
            "amount": 7500
          }
        ],
        "message": "0",
        "token": "#{TOKEN_DEFAULT}",
        "prev_hash": "0",
        "sign_r": "0",
        "sign_s": "0"
      }
    ],
    "nonce": 13464266234315212144,
    "prev_hash": "163b5df7a9eaeaf6972cf1b72f691f3ccd2d4a37591b260b6d64bba54c0066a7",
    "merkle_tree_root": "16213992f29533ee88664437ad509d25856db289"
  }
    }
    Block.from_json(json)
  end

  def block_4
    json = %{
      {
    "index": 4,
    "transactions": [
      {
        "id": "c7aeb946302384e4cb83365b73e47150f5c7c8ce93935a085f8dd785e84073f3",
        "action": "head",
        "senders": [],
        "recipients": [
          {
            "address": "TTBjOGYyMDJjZjVmNjg0YzhmNTBlNTRmNGQ3ZjFiZDRkNzE4NTkzODM2NDlmODZi",
            "amount": 2500
          },
          {
            "address": "TTA4NjNiMjIzNjMwYjViOGVmMmYwZjU0YTFkNTE5YmQ2MWIyYmFiOGIyODVlNTk5",
            "amount": 7500
          }
        ],
        "message": "0",
        "prev_hash": "0",
        "sign_r": "0",
        "sign_s": "0"
      }
    ],
    "nonce": 11260396040783499427,
    "prev_hash": "4db27287cf41be06ec066b405c828566a1da41273486e69e2e222ec5d0700679",
    "merkle_tree_root": "e5cc88f1c6c97ddc807d8e806ce4caf9b893330d"
  }
    }
    Block.from_json(json)
  end

  def block_5
    json = %{
      {
    "index": 5,
    "transactions": [
      {
        "id": "1c4c5699d3837dfb406c054acc5644266befa4ab72a937ea9eaa7c4c4edb2ece",
        "action": "head",
        "senders": [],
        "recipients": [
          {
            "address": "TTBjOGYyMDJjZjVmNjg0YzhmNTBlNTRmNGQ3ZjFiZDRkNzE4NTkzODM2NDlmODZi",
            "amount": 2500
          },
          {
            "address": "TTA4NjNiMjIzNjMwYjViOGVmMmYwZjU0YTFkNTE5YmQ2MWIyYmFiOGIyODVlNTk5",
            "amount": 7500
          }
        ],
        "message": "0",
        "prev_hash": "0",
        "sign_r": "0",
        "sign_s": "0"
      }
    ],
    "nonce": 13385362284715168141,
    "prev_hash": "2295078aaf6dfac6aaed8b6a7bd253cc36513c81dad402e69b04810e8e6048e1",
    "merkle_tree_root": "7694714cbc5239e4d7b406000a4883b0cbbf41ad"
  }
    }
    Block.from_json(json)
  end

  def block_6
    json = %{
      {
    "index": 6,
    "transactions": [
      {
        "id": "1e65a6bc52ea9a979cbb8782b19d7a57cbe70cefe1b95ba90fbd493ca51f7a85",
        "action": "head",
        "senders": [],
        "recipients": [
          {
            "address": "TTBjOGYyMDJjZjVmNjg0YzhmNTBlNTRmNGQ3ZjFiZDRkNzE4NTkzODM2NDlmODZi",
            "amount": 2500
          },
          {
            "address": "TTA4NjNiMjIzNjMwYjViOGVmMmYwZjU0YTFkNTE5YmQ2MWIyYmFiOGIyODVlNTk5",
            "amount": 7500
          }
        ],
        "message": "0",
        "prev_hash": "0",
        "sign_r": "0",
        "sign_s": "0"
      }
    ],
    "nonce": 15944612208300140906,
    "prev_hash": "787bc7571af8fe0594caebf42e07f90c410ef05844c90854327ac8d1ea56f48b",
    "merkle_tree_root": "73d4ba5b4e3ca9f2614fdb70364e08158c2a9a79"
  }
    }
    Block.from_json(json)
  end

  def block_7
    json = %{
      {
    "index": 7,
    "transactions": [
      {
        "id": "65cb19d1b4a1dc800e309c4209a1ff1a0e640441061df0310cacd94dffa560d3",
        "action": "head",
        "senders": [],
        "recipients": [
          {
            "address": "TTBjOGYyMDJjZjVmNjg0YzhmNTBlNTRmNGQ3ZjFiZDRkNzE4NTkzODM2NDlmODZi",
            "amount": 2500
          },
          {
            "address": "TTA4NjNiMjIzNjMwYjViOGVmMmYwZjU0YTFkNTE5YmQ2MWIyYmFiOGIyODVlNTk5",
            "amount": 7500
          }
        ],
        "message": "0",
        "prev_hash": "0",
        "sign_r": "0",
        "sign_s": "0"
      }
    ],
    "nonce": 9047169216954437053,
    "prev_hash": "249106a47bc92dd43c068db99e92e034c132ffdfe78fc22078f55771a71c02f5",
    "merkle_tree_root": "ac101de15327d1c439e141b19202f50d30b5f2b6"
  }
    }
    Block.from_json(json)
  end

  def block_8
    json = %{
      {
    "index": 8,
    "transactions": [
      {
        "id": "5c244b1f7a75b9421a3d120446b819432f0c73997f0ecbb10adc2749f0d95443",
        "action": "head",
        "senders": [],
        "recipients": [
          {
            "address": "TTBjOGYyMDJjZjVmNjg0YzhmNTBlNTRmNGQ3ZjFiZDRkNzE4NTkzODM2NDlmODZi",
            "amount": 2500
          },
          {
            "address": "TTA4NjNiMjIzNjMwYjViOGVmMmYwZjU0YTFkNTE5YmQ2MWIyYmFiOGIyODVlNTk5",
            "amount": 7500
          }
        ],
        "message": "0",
        "prev_hash": "0",
        "sign_r": "0",
        "sign_s": "0"
      }
    ],
    "nonce": 14548740937717102308,
    "prev_hash": "a9f234ce1b5b23225be373925f8e6ecc0dc1f8f68f5dbfa1262a1248aba96661",
    "merkle_tree_root": "ac839ef0ec75181faf6251ff7044e52be93dbcdd"
  }
    }
    Block.from_json(json)
  end

  def block_9
    json = %{
      {
    "index": 9,
    "transactions": [
      {
        "id": "66db8c31cb20eedadbe825305fc542dbc113082f7e7e49a2f0d7001c147f656b",
        "action": "head",
        "senders": [],
        "recipients": [
          {
            "address": "TTBjOGYyMDJjZjVmNjg0YzhmNTBlNTRmNGQ3ZjFiZDRkNzE4NTkzODM2NDlmODZi",
            "amount": 2500
          },
          {
            "address": "TTA4NjNiMjIzNjMwYjViOGVmMmYwZjU0YTFkNTE5YmQ2MWIyYmFiOGIyODVlNTk5",
            "amount": 7500
          }
        ],
        "message": "0",
        "prev_hash": "0",
        "sign_r": "0",
        "sign_s": "0"
      }
    ],
    "nonce": 16958131682057411545,
    "prev_hash": "b13d9530ee0b4872fa4c01035b414b17113a1ec9e7a55b349dbc8bb051c0e71e",
    "merkle_tree_root": "2621becb962b817e870813267cfc26f1ca8b470d"
  }
    }
    Block.from_json(json)
  end

  def block_10
    json = %{
      {
    "index": 10,
    "transactions": [
      {
        "id": "8fc33ce4ca8e0953312a31085823c535014484541d2414b2c9da08deccdaa45f",
        "action": "head",
        "senders": [],
        "recipients": [
          {
            "address": "TTBjOGYyMDJjZjVmNjg0YzhmNTBlNTRmNGQ3ZjFiZDRkNzE4NTkzODM2NDlmODZi",
            "amount": 2500
          },
          {
            "address": "TTA4NjNiMjIzNjMwYjViOGVmMmYwZjU0YTFkNTE5YmQ2MWIyYmFiOGIyODVlNTk5",
            "amount": 7500
          }
        ],
        "message": "0",
        "prev_hash": "0",
        "sign_r": "0",
        "sign_s": "0"
      }
    ],
    "nonce": 9587759897189510347,
    "prev_hash": "d286ad94158925bf888599a03fc7fd5c4a3c4c384197cfbd4c3f799e43eeff92",
    "merkle_tree_root": "f288e4243b156b0da35d9e98d3c52594fe7e14d4"
  }
    }
    Block.from_json(json)
  end

  def block_2_invalid
    json = %{
      {
    "index": 2,
    "transactions": [
      {
        "id": "7d925a249d161d895be689d8369c718e0800f8d735fc0fc46dfb09c4862de9e7",
        "action": "head",
        "senders": [],
        "recipients": [
          {
            "address": "TTBjOGYyMDJjZjVmNjg0YzhmNTBlNTRmNGQ3ZjFiZDRkNzE4NTkzODM2NDlmODZi",
            "amount": 12500
          },
          {
            "address": "TTA4NjNiMjIzNjMwYjViOGVmMmYwZjU0YTFkNTE5YmQ2MWIyYmFiOGIyODVlNTk5",
            "amount": 7500
          }
        ],
        "message": "0",
        "prev_hash": "0",
        "sign_r": "0",
        "sign_s": "0"
      }
    ],
    "nonce": 11121314448198599040,
    "prev_hash": "a50254a09ee8b6325e2c044048dde963b8d2433817f13fbb829a9ac96c1dc68a",
    "merkle_tree_root": "3f1a5c8c4bf63354a0a4bb5915c7484d5adc2a38"
  }
    }
    Block.from_json(json)
  end
end
