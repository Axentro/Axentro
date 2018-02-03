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
        "id": "612dded4b67f31ef5a0bc89a2f045fea5f247b3d42fbc3fee46a5af43e5bd62e",
        "action": "head",
        "senders": [],
        "recipients": [
          {
            "address": "VDBiNzFhYmFlYmU2MjI0YzJmYTc5Nzg0OTYwZDc3YTE3Yjg4ODM3MTUyNmFiYTZl",
            "amount": 10000
          }
        ],
        "message": "0",
        "prev_hash": "0",
        "sign_r": "0",
        "sign_s": "0"
      }
    ],
    "nonce": 2904846426898123243,
    "prev_hash": "5396e18efa80a8e891c417fff862d7cad171465e65bc4b4e5e1c1c3ab0aeb88f",
    "merkle_tree_root": "bc5611dd1c13ee3fe971ebb6ae7776ceae404754"
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
        "id": "58a46001b5568a88fc2ea09ab15571ddfa1b8458f638c1c74ff4d7ee652d556d",
        "action": "head",
        "senders": [],
        "recipients": [
          {
            "address": "VDBiNzFhYmFlYmU2MjI0YzJmYTc5Nzg0OTYwZDc3YTE3Yjg4ODM3MTUyNmFiYTZl",
            "amount": 2500
          },
          {
            "address": "VDAxYjcyM2VhNmU1MzhjZDE0MDEyZmZjOTZjMTg3YmM2NzdlYTFlNWExNDIyZjVh",
            "amount": 7500
          }
        ],
        "message": "0",
        "prev_hash": "0",
        "sign_r": "0",
        "sign_s": "0"
      }
    ],
    "nonce": 15503140033762618189,
    "prev_hash": "8ee860f9b3349905085e1b49acaff7f76bc2ce08a109ece1f3f2f0acf3b91255",
    "merkle_tree_root": "7d1136d20c414b816557cffdb3b05622263d035a"
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
       "id": "ff41df01e3d8db88b9728e6ebaece3010397015e1422cd36adbb46dcfb050c9f",
       "action": "head",
       "senders": [],
       "recipients": [
         {
           "address": "VDBiNzFhYmFlYmU2MjI0YzJmYTc5Nzg0OTYwZDc3YTE3Yjg4ODM3MTUyNmFiYTZl",
           "amount": 2500
         },
         {
           "address": "VDAxYjcyM2VhNmU1MzhjZDE0MDEyZmZjOTZjMTg3YmM2NzdlYTFlNWExNDIyZjVh",
           "amount": 7500
         }
       ],
       "message": "0",
       "prev_hash": "0",
       "sign_r": "0",
       "sign_s": "0"
     }
   ],
   "nonce": 11577508140005022087,
   "prev_hash": "740aa29e17f2bbb6793a54b6ad1322f234d3297054521fb68406770fdce9ae16",
   "merkle_tree_root": "9941fbaa8b7d7a63ef961cbffc6c4d23372e40c2"
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
      "id": "36ebd7571c617cecb49235c8367a59f449c34a20ec4235c31ac46dcc7a8836df",
      "action": "head",
      "senders": [],
      "recipients": [
        {
          "address": "VDBiNzFhYmFlYmU2MjI0YzJmYTc5Nzg0OTYwZDc3YTE3Yjg4ODM3MTUyNmFiYTZl",
          "amount": 2500
        },
        {
          "address": "VDAxYjcyM2VhNmU1MzhjZDE0MDEyZmZjOTZjMTg3YmM2NzdlYTFlNWExNDIyZjVh",
          "amount": 7500
        }
      ],
      "message": "0",
      "prev_hash": "0",
      "sign_r": "0",
      "sign_s": "0"
    }
  ],
  "nonce": 2152713874635269483,
  "prev_hash": "f2b077540d751dd25fdd3682d118f4d190c4da2072e08e9fcce448ffd47fc4f3",
  "merkle_tree_root": "fcaf9df3f1d6517418518bd927299e647754623e"
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
        "id": "c194bac1e5b61584886435f29275c69dfce2d2f70008a429015e181310d4b82f",
        "action": "head",
        "senders": [],
        "recipients": [
          {
            "address": "VDBiNzFhYmFlYmU2MjI0YzJmYTc5Nzg0OTYwZDc3YTE3Yjg4ODM3MTUyNmFiYTZl",
            "amount": 2500
          },
          {
            "address": "VDAxYjcyM2VhNmU1MzhjZDE0MDEyZmZjOTZjMTg3YmM2NzdlYTFlNWExNDIyZjVh",
            "amount": 7500
          }
        ],
        "message": "0",
        "prev_hash": "0",
        "sign_r": "0",
        "sign_s": "0"
      }
    ],
    "nonce": 15024682274700691373,
    "prev_hash": "393dfb99353c5c0a5cb85489af5946a7176227f7e4b78bc9a163adbadc41e88b",
    "merkle_tree_root": "0eec5fa02f766cbdd6b03e91769a597102aa6f85"
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
        "id": "368fc7235ddb090ba5c274c6e5e391a662b2f198b73906f0ee7e4dbbc15b2180",
        "action": "head",
        "senders": [],
        "recipients": [
          {
            "address": "VDBiNzFhYmFlYmU2MjI0YzJmYTc5Nzg0OTYwZDc3YTE3Yjg4ODM3MTUyNmFiYTZl",
            "amount": 2500
          },
          {
            "address": "VDAxYjcyM2VhNmU1MzhjZDE0MDEyZmZjOTZjMTg3YmM2NzdlYTFlNWExNDIyZjVh",
            "amount": 7500
          }
        ],
        "message": "0",
        "prev_hash": "0",
        "sign_r": "0",
        "sign_s": "0"
      }
    ],
    "nonce": 1169291176586852846,
    "prev_hash": "6e9d6c496d75345fd8e3904e08273107c75e800c8e600824e21c08c089d97715",
    "merkle_tree_root": "b7383c24ec17309841a15cbb65e5f7210a17b3b1"
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
        "id": "d9f478abd647dc836aa6f54818b7b05719e0f824b8d8904bba8702cfce9e51e8",
        "action": "head",
        "senders": [],
        "recipients": [
          {
            "address": "VDBiNzFhYmFlYmU2MjI0YzJmYTc5Nzg0OTYwZDc3YTE3Yjg4ODM3MTUyNmFiYTZl",
            "amount": 2500
          },
          {
            "address": "VDAxYjcyM2VhNmU1MzhjZDE0MDEyZmZjOTZjMTg3YmM2NzdlYTFlNWExNDIyZjVh",
            "amount": 7500
          }
        ],
        "message": "0",
        "prev_hash": "0",
        "sign_r": "0",
        "sign_s": "0"
      }
    ],
    "nonce": 40660323347632100,
    "prev_hash": "dc143454bc0cc303f6a615d8158ed229fc75375ce35d5d918ca2747778ea07bd",
    "merkle_tree_root": "0bfed704976ff9e53a3dc20e6ea4b5adbda52998"
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
        "id": "60ad1a87d5dd5490554c6cee20997074263d40ff716be8c469748b219278ba71",
        "action": "head",
        "senders": [],
        "recipients": [
          {
            "address": "VDBiNzFhYmFlYmU2MjI0YzJmYTc5Nzg0OTYwZDc3YTE3Yjg4ODM3MTUyNmFiYTZl",
            "amount": 2500
          },
          {
            "address": "VDAxYjcyM2VhNmU1MzhjZDE0MDEyZmZjOTZjMTg3YmM2NzdlYTFlNWExNDIyZjVh",
            "amount": 7500
          }
        ],
        "message": "0",
        "prev_hash": "0",
        "sign_r": "0",
        "sign_s": "0"
      }
    ],
    "nonce": 17345917019112288963,
    "prev_hash": "3845af0536f19acda092af964568c0d45e5035f33fed9a524ecbf101e8fc03d4",
    "merkle_tree_root": "3b36d207ef0243c34ce89880a87276d0816e2d5d"
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
        "id": "8d555a5473e692ac9c530df64762d230a65f8be92c408a2c02978e46ceb5aa9b",
        "action": "head",
        "senders": [],
        "recipients": [
          {
            "address": "VDBiNzFhYmFlYmU2MjI0YzJmYTc5Nzg0OTYwZDc3YTE3Yjg4ODM3MTUyNmFiYTZl",
            "amount": 2500
          },
          {
            "address": "VDAxYjcyM2VhNmU1MzhjZDE0MDEyZmZjOTZjMTg3YmM2NzdlYTFlNWExNDIyZjVh",
            "amount": 7500
          }
        ],
        "message": "0",
        "prev_hash": "0",
        "sign_r": "0",
        "sign_s": "0"
      }
    ],
    "nonce": 1046000349784630844,
    "prev_hash": "fd3c97d8780cd4ce5cdf53a0b4637721a90dcdd4d74d5ec312cd09f81e512647",
    "merkle_tree_root": "f33eabbcd7f0f109e67bcf8a686a7b4af6838654"
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
        "id": "83cf0322ead6593c94748ac129c4c5bbde27a5578c204af97b21e0a59bf10ae2",
        "action": "head",
        "senders": [],
        "recipients": [
          {
            "address": "VDBiNzFhYmFlYmU2MjI0YzJmYTc5Nzg0OTYwZDc3YTE3Yjg4ODM3MTUyNmFiYTZl",
            "amount": 2500
          },
          {
            "address": "VDAxYjcyM2VhNmU1MzhjZDE0MDEyZmZjOTZjMTg3YmM2NzdlYTFlNWExNDIyZjVh",
            "amount": 7500
          }
        ],
        "message": "0",
        "prev_hash": "0",
        "sign_r": "0",
        "sign_s": "0"
      }
    ],
    "nonce": 8523480423442361452,
    "prev_hash": "0ea46301b8109fc50094f8ffe020f1b98ab8edc515cbe1416b7d4d33e75392f8",
    "merkle_tree_root": "fb413020daac2b6b55b0ce8be73da129fcd41880"
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
      "id": "58a46001b5568a88fc2ea09ab15571ddfa1b8458f638c1c74ff4d7ee652d556d",
      "action": "head",
      "senders": [],
      "recipients": [
        {
          "address": "VDBiNzFhYmFlYmU2MjI0YzJmYTc5Nzg0OTYwZDc3YTE3Yjg4ODM3MTUyNmFiYTZl",
          "amount": 12500
        },
        {
          "address": "VDAxYjcyM2VhNmU1MzhjZDE0MDEyZmZjOTZjMTg3YmM2NzdlYTFlNWExNDIyZjVh",
          "amount": 7500
        }
      ],
      "message": "0",
      "prev_hash": "0",
      "sign_r": "0",
      "sign_s": "0"
    }
  ],
  "nonce": 15503140033762618189,
  "prev_hash": "8ee860f9b3349905085e1b49acaff7f76bc2ce08a109ece1f3f2f0acf3b91255",
  "merkle_tree_root": "7d1136d20c414b816557cffdb3b05622263d035a"
}
    }
    Block.from_json(json)
  end
end
