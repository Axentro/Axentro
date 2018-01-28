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
        "index":1,
        "transactions":[
                          {
                            "id":"f804d856480e6a5fc2a9df77c2f761814e6ac63b722386c2d04a1d2b52a9e069",
                           "action":"head",
                           "senders":[],
                           "recipients":[
                                           {
                                             "address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
                                            "amount":10000
                                           }
                                         ],
                           "message":"0",
                           "prev_hash":"0",
                           "sign_r":"0",
                           "sign_s":"0"
                          }
                        ],
       "nonce":9837448705800144284,
       "prev_hash":"5396e18efa80a8e891c417fff862d7cad171465e65bc4b4e5e1c1c3ab0aeb88f",
       "merkle_tree_root":"3f38bc1555ee54f7287e099e58ec699764035036"
      }
    }
    Block.from_json(json)
  end

  def block_2
    json = %{
      {
        "index":2,
        "transactions":[
                          {
                            "id":"73478665802282437a537a72985befb106d3864e10ca43bab44ee96406256586",
                           "action":"head",
                           "senders":[],
                           "recipients":[
                                           {
                                             "address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
                                            "amount":2500
                                           }
                                           ,{
                                             "address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
                                             "amount":7500
                                           }
                                         ],
                           "message":"0",
                           "prev_hash":"0",
                           "sign_r":"0",
                           "sign_s":"0"
                          }
                        ],
       "nonce":4531115808962198085,
       "prev_hash":"7cbc286a6db06aa97ba57f3f39bf06586c2f18cfcc6495023d5cdd012abeec60",
       "merkle_tree_root":"c96d6d7d9cb53a61316dfac05b913d61a3ec02c4"
      }
    }
    Block.from_json(json)
  end

  def block_3
    json = %{
      {
        "index":3,
        "transactions":[
                          {
                            "id":"040d18deb79d43008b8ef881582f39973b91d182c8fd6c7912d66405b2e3eee7",
                           "action":"head",
                           "senders":[],
                           "recipients":[
                                           {
                                             "address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
                                            "amount":2500
                                           },
                                           {
                                             "address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
                                            "amount":7500
                                           }
                                         ],
                           "message":"0",
                           "prev_hash":"0",
                           "sign_r":"0",
                           "sign_s":"0"
                          }
                        ],
       "nonce":12703492358992392334,
       "prev_hash":"c02f8c2473d70974cecae25d8ed647ecd190fbc65974ec028d9bd5c67b9228b3",
       "merkle_tree_root":"a68238e91020663ef12e915e7ed7483e292f63cb"
      }
    }
    Block.from_json(json)
  end

  def block_4
    json = %{
      {
        "index":4,
        "transactions":[
                          {
                            "id":"d0dfea3efeaf7921a6fc88ddcddb7969a74233d70bd4f322940929ad31ed776d",
                           "action":"head",
                           "senders":[],
                           "recipients":[
                                           {
                                             "address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
                                            "amount":10000
                                           }
                                         ],
                           "message":"0",
                           "prev_hash":"0",
                           "sign_r":"0",
                           "sign_s":"0"
                          }
                        ],
       "nonce":5858896090230544209,
       "prev_hash":"161aa54e783b5912cedbff435f281dad7706c14fd4da8053687a20b89e308983",
       "merkle_tree_root":"efc19e65518848efce6cde777bfe788912fba5e0"
      }
    }
    Block.from_json(json)
  end

  def block_5
    json = %{
      {
        "index":5,
        "transactions":[
                          {
                            "id":"60653b3db09cfa3f0cd344b98c63b7b7e4191d3202b94338db80525362dc9f09",
                           "action":"head",
                           "senders":[],
                           "recipients":[
                                           {
                                             "address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
                                            "amount":2500
                                           },
                                           {
                                             "address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
                                            "amount":7500
                                           }
                                         ],
                           "message":"0",
                           "prev_hash":"0",
                           "sign_r":"0",
                           "sign_s":"0"
                          }
                        ],
       "nonce":4405480561502108575,
       "prev_hash":"f810b0e2292554fb7cdbd8cadf54847ab7db261139fcc7e52b7ef73cc12ea8b9",
       "merkle_tree_root":"8149f94bf7e4a07013c795210e480f120e1c334d"
      }
    }
    Block.from_json(json)
  end

  def block_6
    json = %{
      {
        "index":6,
        "transactions":[
                          {
                            "id":"d1775fc5124f24921248f847161d166cfeb16c0b5c6e5317770fe8c008d61470",
                           "action":"head",
                           "senders":[],
                           "recipients":[
                                           {
                                             "address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
                                            "amount":2500
                                           },
                                           {
                                             "address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
                                            "amount":7500
                                           }
                                         ],
                           "message":"0",
                           "prev_hash":"0",
                           "sign_r":"0",
                           "sign_s":"0"
                          }
                        ],
       "nonce":7413164795613819364,
       "prev_hash":"68c44f4fc667fe8f1682291be86b1a88265973e984c72f726cac37c137d1e8de",
       "merkle_tree_root":"ed1f501abcb34b728182c8269b1da18638af162a"
      }
    }
    Block.from_json(json)
  end

  def block_7
    json = %{
      {
        "index":7,
        "transactions":[
                          {
                            "id":"6372433f05ee2892819e5985374690a46f0b9e53cd78e106da89868200082ecf",
                           "action":"head",
                           "senders":[],
                           "recipients":[
                                           {
                                             "address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
                                            "amount":2500
                                           },
                                           {
                                             "address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
                                            "amount":7500
                                           }
                                         ],
                           "message":"0",
                           "prev_hash":"0",
                           "sign_r":"0",
                           "sign_s":"0"
                          }
                        ],
       "nonce":10747415878307008285,
       "prev_hash":"83a7ad0edeaa2ece2b9ec8367eaa9321e334f047af3f44b111df261259712acc",
       "merkle_tree_root":"5a7f3da9b34f280417a7fa38e32dbab66fdd2143"
      }
    }
    Block.from_json(json)
  end

  def block_8
    json = %{
      {
        "index":8,
        "transactions":[
                          {
                            "id":"eae201f21f5a87a993c6e63b76dd67952e614bbb1a3e11edf3a4a87d3833a178",
                           "action":"head",
                           "senders":[],
                           "recipients":[
                                           {
                                             "address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
                                            "amount":2500
                                           },
                                           {
                                             "address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
                                            "amount":7500
                                           }
                                         ],
                           "message":"0",
                           "prev_hash":"0",
                           "sign_r":"0",
                           "sign_s":"0"
                          }
                        ],
       "nonce":429911461262732095,
       "prev_hash":"7a81a9b75959dbacbebc8e04995645ca6e779a8221980691290aff045b1e3c20",
       "merkle_tree_root":"2ae5132493c63d255e750f6c2311069ec5f1c1fb"
      }
    }
    Block.from_json(json)
  end

  def block_9
    json = %{
      {
        "index":9,
        "transactions":[
                          {
                            "id":"e973eec50de293afa387512b5b48c2caaa30ca4112fb06d61ffc15d787db4156",
                           "action":"head",
                           "senders":[],
                           "recipients":[
                                           {
                                             "address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
                                            "amount":2500
                                           },
                                           {
                                             "address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
                                            "amount":7500
                                           }
                                         ],
                           "message":"0",
                           "prev_hash":"0",
                           "sign_r":"0",
                           "sign_s":"0"
                          }
                        ],
       "nonce":10090336744143692275,
       "prev_hash":"6bbbb325eee060b31d0868b6e5a5675882357250ccbde66e84c979e90f55dab0",
       "merkle_tree_root":"a3fe3cf077a54a3c9dcea9df634bad0ef8eaa1e7"
      }
    }
    Block.from_json(json)
  end

  def block_10
    json = %{
      {
        "index":10,
        "transactions":[
                          {
                            "id":"74c1327450701bf33bb3af8bce3958f792772a5b9af88074efabb7e396230290",
                           "action":"head",
                           "senders":[],
                           "recipients":[
                                           {
                                             "address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
                                            "amount":2500
                                           },
                                           {
                                             "address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
                                            "amount":7500
                                           }
                                         ],
                           "message":"0",
                           "prev_hash":"0",
                           "sign_r":"0",
                           "sign_s":"0"
                          }
                        ],
       "nonce":2651254945948760122,
       "prev_hash":"5e4912e0aa29d8f5ea624949fe3ff6fd95903b13f77d71425a87782e603fd9f8",
       "merkle_tree_root":"127a0a1531fc66942b0f7e079be7992694606c4f"
      }
    }
    Block.from_json(json)
  end

  def block_2_invalid
    json = %{
      {
        "index":2,
        "transactions":[
                          {
                            "id":"73478665802282437a537a72985befb106d3864e10ca43bab44ee96406256586",
                           "action":"head",
                           "senders":[],
                           "recipients":[
                                           {
                                             "address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
                                            "amount":12500
                                           }
                                           ,{
                                             "address":"VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
                                             "amount":7500
                                           }
                                         ],
                           "message":"0",
                           "prev_hash":"0",
                           "sign_r":"0",
                           "sign_s":"0"
                          }
                        ],
       "nonce":4531115808962198085,
       "prev_hash":"7cbc286a6db06aa97ba57f3f39bf06586c2f18cfcc6495023d5cdd012abeec60",
       "merkle_tree_root":"c96d6d7d9cb53a61316dfac05b913d61a3ec02c4"
      }
    }
    Block.from_json(json)
  end
end
