require "./../../spec_helper"

include Sushi::Core

describe UTXO do

  describe "#get" do

    it "should return 0.0 when the number of blocks is less than confirmations" do
      chain = [genesis_block, block_1]
      utxo = UTXO.new
      utxo.record(chain)

      address = block_1.transactions.first.recipients.first[:address]
      utxo.get(address).should eq(0.0)
    end

    it "should return address amount when the number of blocks is greater than confirmations" do
      chain = [genesis_block, block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
      utxo = UTXO.new
      utxo.record(chain)

      address = block_1.transactions.first.recipients.first[:address]
      expected_amount = chain.reject{|blk| blk.prev_hash == "genesis"}.flat_map{|blk| blk.transactions.first.recipients.select{|r| r[:address] == address} }.map{|x| x[:amount]}.sum

      utxo.get(address).should eq(expected_amount)
    end

    context "when address does not exist" do

      it "should return 0.0 when the number of blocks is less than confirmations and the address is not found" do
        chain = [genesis_block, block_1]
        utxo = UTXO.new
        utxo.record(chain)

        utxo.get("address-does-not-exist").should eq(0.0)
      end

      it "should return address amount when the number of blocks is greater than confirmations and the address is not found" do
        chain = [genesis_block, block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
        utxo = UTXO.new
        utxo.record(chain)

        utxo.get("address-does-not-exist").should eq(0.0)
      end

    end
  end

  describe "#get_unconfirmed" do

    it "should get unconfirmed transactions amount for the supplied address in the supplied transactions" do
      chain = [genesis_block, block_1]
      utxo = UTXO.new
      utxo.record(chain)

      transactions = chain.reject{|blk| blk.prev_hash == "genesis"}.flat_map{|blk| blk.transactions }
      address = block_1.transactions.first.recipients.first[:address]
      expected_amount = transactions.flat_map{|txn| txn.recipients.select{|r| r[:address] == address} }.map{|x| x[:amount]}.sum * 2
      utxo.get_unconfirmed(address, transactions).should eq(expected_amount)
    end

    it "should get unconfirmed transactions amount for the supplied address when no transactions are supplied" do
      chain = [genesis_block, block_1]
      utxo = UTXO.new
      utxo.record(chain)

      transactions = [] of Transaction
      address = block_1.transactions.first.recipients.first[:address]
      expected_amount = chain.reject{|blk| blk.prev_hash == "genesis"}.flat_map{|blk| blk.transactions.first.recipients.select{|r| r[:address] == address} }.map{|x| x[:amount]}.sum
      utxo.get_unconfirmed(address, transactions).should eq(expected_amount)
    end

    context "when chain is empty" do

      it "should get unconfirmed transactions amount for the supplied address when no transactions are supplied and the chain is empty" do
        chain = [] of Block
        utxo = UTXO.new
        utxo.record(chain)

        transactions = [] of Transaction
        address = block_1.transactions.first.recipients.first[:address]
        utxo.get_unconfirmed(address, transactions).should eq(0.0)
      end

      it "should get unconfirmed transactions when no transactions are supplied and the chain is empty and the address is unknown" do
        chain = [] of Block
        utxo = UTXO.new
        utxo.record(chain)

        transactions = [] of Transaction
        utxo.get_unconfirmed("address-does-not-exist", transactions).should eq(0.0)
      end
    end
  end

  describe "#get_unconfirmed_recorded" do

    it "should return 0.0 when there are no transactions" do
      chain = [] of Block
      utxo = UTXO.new
      utxo.record(chain)

      address = block_1.transactions.first.recipients.first[:address]
      utxo.get_unconfirmed_recorded(address).should eq(0.0)
    end

    it "should return the correct amount when transactions" do
      chain = [genesis_block, block_1]
      utxo = UTXO.new
      utxo.record(chain)

      address = block_1.transactions.first.recipients.first[:address]
      expected_amount = chain.reject{|blk| blk.prev_hash == "genesis"}.flat_map{|blk| blk.transactions.first.recipients.select{|r| r[:address] == address} }.map{|x| x[:amount]}.sum
      utxo.get_unconfirmed_recorded(address).should eq(expected_amount)
    end

    it "should return 0.0 when an non existing address is supplied" do
      chain = [genesis_block, block_1]
      utxo = UTXO.new
      utxo.record(chain)

      utxo.get_unconfirmed_recorded("address-does-not-exist").should eq(0.0)
    end
  end

  describe "#index" do

    it "should return a block index for supplied transaction id" do
      chain = [genesis_block, block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
      utxo = UTXO.new
      utxo.record(chain)

      transaction_id = block_1.transactions.first.id
      utxo.index(transaction_id).should eq(1_i64)
    end

    it "should return nil when supplied transaction id is not found" do
      chain = [genesis_block, block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
      utxo = UTXO.new
      utxo.record(chain)

      utxo.index("transaction-id-does-not-exist").should be_nil
    end

  end

  it "should clear the internal transaction lists with #clear" do
    chain = [genesis_block, block_1, block_2, block_3, block_4, block_5, block_6, block_7, block_8, block_9, block_10]
    utxo = UTXO.new
    utxo.record(chain)

    utxo.@transaction_indices.size.should eq(10)
    utxo.@utxo_internal.size.should eq(11)

    utxo.clear

    utxo.@transaction_indices.size.should eq(0)
    utxo.@utxo_internal.size.should eq(0)
  end

  pending "#show" do
    # This method is not used currently as the only caller is commented out in the record method.
    # Need to figure out if this is still needed and fix or delete
  end

end


def genesis_block
  json = %{{
     "index": 0,
     "transactions": [],
     "nonce": 0,
     "prev_hash": "genesis",
     "merkle_tree_root": ""
   }}
  Block.from_json(json)
end

def block_1
  json = %{{
    "index": 1,
    "transactions": [
      {
        "id": "9d6078b87d0378b787e196c63dcdebed91a1249b4fdd35fb751037588ab332a5",
        "action": "head",
        "senders": [],
        "recipients": [
          {
            "address": "VDAyNTk0YjdlMTc4N2FkODRmYTU0YWZmODM1YzQzOTA2YTEzY2NjYmMyNjdkYjVm",
            "amount": 10000.0
          }
        ],
        "message": "0",
        "prev_hash": "0",
        "sign_r": "0",
        "sign_s": "0"
      }
    ],
    "nonce": 8455396812870916791,
    "prev_hash": "5396e18efa80a8e891c417fff862d7cad171465e65bc4b4e5e1c1c3ab0aeb88f",
    "merkle_tree_root": "2bba8194186eb13cb6a61d16f5dedbbf15006fab"
  }}
  Block.from_json(json)
end

def block_2
  json = %{{
    "index": 2,
    "transactions": [
      {
        "id": "134c5bfc92a60bc6e1af49341c94133b7f5bb7307ca24fc593d84bc57bd34d13",
        "action": "head",
        "senders": [],
        "recipients": [
          {
            "address": "VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
            "amount": 7500.0
          },
          {
            "address": "VDAyNTk0YjdlMTc4N2FkODRmYTU0YWZmODM1YzQzOTA2YTEzY2NjYmMyNjdkYjVm",
            "amount": 2500.0
          }
        ],
        "message": "0",
        "prev_hash": "0",
        "sign_r": "0",
        "sign_s": "0"
      }
    ],
    "nonce": 2016016943360382502,
    "prev_hash": "4f1fd55029dd7e289df673ee8e5d045a25a2559b22b74d4fa1ce38d1e7070efb",
    "merkle_tree_root": "fa2c1679d9f4fba388a936efc06d9c4f8ac4c920"
  }}
  Block.from_json(json)
end

def block_3
  json = %{{
    "index": 3,
    "transactions": [
      {
        "id": "621a7d6a95ce3e703cb1ba069a78293808503ad207186f1f323792d6cad4613a",
        "action": "head",
        "senders": [],
        "recipients": [
          {
            "address": "VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
            "amount": 7500.0
          },
          {
            "address": "VDAyNTk0YjdlMTc4N2FkODRmYTU0YWZmODM1YzQzOTA2YTEzY2NjYmMyNjdkYjVm",
            "amount": 2500.0
          }
        ],
        "message": "0",
        "prev_hash": "0",
        "sign_r": "0",
        "sign_s": "0"
      }
    ],
    "nonce": 8801985064448438023,
    "prev_hash": "d413d8fc1e502f70b6a47baa14f9f76a24e5c7ee18ac88dc005232d7a5a83198",
    "merkle_tree_root": "e4d57a1337f41d7dc723c9e46d0cbe1901b94077"
  }}
  Block.from_json(json)
end

def block_4
  json = %{{
      "index": 4,
      "transactions": [
        {
          "id": "7700f5ec66aa9e8736e256649b85525ef121cb506f745b8bd8902d0bfc62fd61",
          "action": "head",
          "senders": [],
          "recipients": [
            {
              "address": "VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
              "amount": 7500.0
            },
            {
              "address": "VDAyNTk0YjdlMTc4N2FkODRmYTU0YWZmODM1YzQzOTA2YTEzY2NjYmMyNjdkYjVm",
              "amount": 2500.0
            }
          ],
          "message": "0",
          "prev_hash": "0",
          "sign_r": "0",
          "sign_s": "0"
        }
      ],
      "nonce": 14017229810673792798,
      "prev_hash": "665058fe412ba1372b5a3d43093b1df2c0a85d7787b57062aef9b8ac16d54d28",
      "merkle_tree_root": "e5f57eb7a75d28ffcca6823b9ec32205b8375e9b"
    }}
  Block.from_json(json)
end

def block_5
  json = %{{
    "index": 5,
    "transactions": [
      {
        "id": "6b303d981308dfac85260e5b27953f6bbd107007f192dcac4afa7b2024262e2e",
        "action": "head",
        "senders": [],
        "recipients": [
          {
            "address": "VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
            "amount": 7500.0
          },
          {
            "address": "VDAyNTk0YjdlMTc4N2FkODRmYTU0YWZmODM1YzQzOTA2YTEzY2NjYmMyNjdkYjVm",
            "amount": 2500.0
          }
        ],
        "message": "0",
        "prev_hash": "0",
        "sign_r": "0",
        "sign_s": "0"
      }
    ],
    "nonce": 7401539816609026185,
    "prev_hash": "7b7a941317270801a93cfd49b8540b0dfdd202347473d415170e90d528ec7855",
    "merkle_tree_root": "22273451d2de851f1a06c4e3095ef7451b03a5c7"
  }}
  Block.from_json(json)
end

def block_6
  json = %{{
      "index": 6,
      "transactions": [
        {
          "id": "4c789672e31b1192427c90b0ffc009bbd8e6de774675c3db1aaa109308e36b39",
          "action": "head",
          "senders": [],
          "recipients": [
            {
              "address": "VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
              "amount": 7500.0
            },
            {
              "address": "VDAyNTk0YjdlMTc4N2FkODRmYTU0YWZmODM1YzQzOTA2YTEzY2NjYmMyNjdkYjVm",
              "amount": 2500.0
            }
          ],
          "message": "0",
          "prev_hash": "0",
          "sign_r": "0",
          "sign_s": "0"
        }
      ],
      "nonce": 8265115058789950132,
      "prev_hash": "15b8085bb3bc64cecc75f4bfdbdb43d996bd895fd9cb5552e1f4e8aa5eb8c99f",
      "merkle_tree_root": "cd50c9426284118312cd64d3d78efaea5f4821c9"
    }}
  Block.from_json(json)
end

def block_7
  json = %{{
      "index": 7,
      "transactions": [
        {
          "id": "21776769c5b8add29a6d10861385027ac4d31a2927026934646788164c5427f5",
          "action": "head",
          "senders": [],
          "recipients": [
            {
              "address": "VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
              "amount": 7500.0
            },
            {
              "address": "VDAyNTk0YjdlMTc4N2FkODRmYTU0YWZmODM1YzQzOTA2YTEzY2NjYmMyNjdkYjVm",
              "amount": 2500.0
            }
          ],
          "message": "0",
          "prev_hash": "0",
          "sign_r": "0",
          "sign_s": "0"
        }
      ],
      "nonce": 5539691655857608185,
      "prev_hash": "206cf1627761bb3ce89a9fb06195fdb757eeae579120fd83051f13710daf107e",
      "merkle_tree_root": "5075952c5f33b869d68fd7c4b0a416ba5d12c9f5"
    }}
  Block.from_json(json)
end

def block_8
  json = %{{
      "index": 8,
      "transactions": [
        {
          "id": "0bac8c5d7bfa34dd85201cb1ad240d71b20caca46767c0fe000c568621611b61",
          "action": "head",
          "senders": [],
          "recipients": [
            {
              "address": "VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
              "amount": 7500.0
            },
            {
              "address": "VDAyNTk0YjdlMTc4N2FkODRmYTU0YWZmODM1YzQzOTA2YTEzY2NjYmMyNjdkYjVm",
              "amount": 2500.0
            }
          ],
          "message": "0",
          "prev_hash": "0",
          "sign_r": "0",
          "sign_s": "0"
        }
      ],
      "nonce": 15858955934280887182,
      "prev_hash": "db1083bea8a8713e123195d328263c38676f23ede8e3bd038403a8691445b075",
      "merkle_tree_root": "4f3c3493c2396b95ad919859cf5202660a5e9b74"
    }}
  Block.from_json(json)
end

def block_9
  json = %{{
    "index": 9,
    "transactions": [
      {
        "id": "ff65a9c6a31396f7c58d35b0d38144d314ed722525973233fa0577ed06f211e4",
        "action": "head",
        "senders": [],
        "recipients": [
          {
            "address": "VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
            "amount": 7500.0
          },
          {
            "address": "VDAyNTk0YjdlMTc4N2FkODRmYTU0YWZmODM1YzQzOTA2YTEzY2NjYmMyNjdkYjVm",
            "amount": 2500.0
          }
        ],
        "message": "0",
        "prev_hash": "0",
        "sign_r": "0",
        "sign_s": "0"
      }
    ],
    "nonce": 17696387324369315964,
    "prev_hash": "69232d2bbff021bb4c44620c60f7b227ba0b7f5518a6e37df3dbc7a50c2fa9f4",
    "merkle_tree_root": "08ae06d3d7db82146d3438256fe16987d6a99b5e"
  }}
  Block.from_json(json)
end

def block_10
  json = %{{
      "index": 10,
      "transactions": [
        {
          "id": "13038bc85a9d93a9e876070f10d97f806947ce451264c2784dcd8f47a06e42cc",
          "action": "head",
          "senders": [],
          "recipients": [
            {
              "address": "VDAyYTVjMDYwZjYyZThkOWM5ODhkZGFkMmM3NzM2MjczZWZhZjIxNDAyNWRmNWQ0",
              "amount": 7500.0
            },
            {
              "address": "VDAyNTk0YjdlMTc4N2FkODRmYTU0YWZmODM1YzQzOTA2YTEzY2NjYmMyNjdkYjVm",
              "amount": 2500.0
            }
          ],
          "message": "0",
          "prev_hash": "0",
          "sign_r": "0",
          "sign_s": "0"
        }
      ],
      "nonce": 17204602413452327067,
      "prev_hash": "78a7ce09ad0662d517dec2f1cf910becfcc5927647d6048d4d9295111ed052e5",
      "merkle_tree_root": "2bebf0f54b9597c3061a464ff7dfc0561eaa9fde"
    }}
  Block.from_json(json)
end
