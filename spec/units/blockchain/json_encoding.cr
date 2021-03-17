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

require "./../../spec_helper"
require "benchmark"

include Axentro::Core
include Hashes
include Units::Utils

describe "Json encoding" do
  # json keys are ordered as specified by the output
  # senders and recipients are ordered by all fields
  it "should encode a transaction based on encoding rules" do
    expected_json = %Q{
        {
            "id":"be8473ea093084461006581b776c2ef1b960ee946a5eaf42f175cd9aace8fd1a",
            "action":"send",
            "message":"0",
            "token":"AXNT",
            "prev_hash":"0",
            "timestamp":1615927723068,
            "scaled":1,
            "kind":"FAST",
            "version":"V1",
            "senders":[
               {
                  "address":"VDAyNThiOWFiN2Q5YWM3ZjUyYTNhYzQwZTY1NDBmYWJkMjczZmVmZThlOTgzMWM4",
                  "public_key":"8b3c61787fb6b07bb20e4a908deca52ef96335e4faaaaca18a227f9d674dcc57",
                  "amount":2000,
                  "fee":1000,
                  "signature":"0"
               },
               {
                  "address":"VDBiYjkyMjY1ZDJlOTNkZmNjN2NmYWFhZTVhMzVlYjZmYjY2YzllNWFjYWY3N2Nh",
                  "public_key":"cd79aa3b76078fb6dbe8199fccbc49a7e0deadbc9370791180e34dbabd65a47e",
                  "amount":5000,
                  "fee":1000,
                  "signature":"0"
               }
            ],
            "recipients":[
               {
                  "address":"VDA4M2YwYTkzZTQxZTQ0NzdjOGRjMDU4ZTkwZTI4OWY1NDNkMDZjYmU3ODQyM2Rk",
                  "amount":2000
               },
               {
                  "address":"VDAwZDRiYTg0MWVlZjE4M2U3OWY2N2E0YmZkZDJjN2JmMWE0ZTViMjE3ZDNmZTU1",
                  "amount":3000
               }
            ]
         }      
    }.gsub(/\s+/,"")
    transaction_1.to_json.should eq(expected_json)
  end

  # block keys are ordered as specified by the output
  # transactions are ordered by timestamp and uuid
  it "should encode a block based on encoding rules" do
    timestamp = 1615971474028_i64
    block = Block.new(2,
      [transaction_1, transaction_2], "nonce", "prev_hash", timestamp,
      17, BlockKind::FAST, "address", "public_key", "signature", "hash", BLOCK_VERSION, HASH_VERSION, "merkle_tree_root")

      hashable_block = SlowBlockNoTimestampV2.from_block(block)
      expected_json = %Q{
        {
            "index":2,
            "nonce":"nonce",
            "prev_hash":"prev_hash",
            "merkle_tree_root":"merkle_tree_root",
            "difficulty":17,
            "address":"address",
            "public_key":"public_key",
            "signature":"signature",
            "hash":"hash",
            "version":"V2",
            "hash_version":"V2",
            "transactions":[
               {
                  "id":"be8473ea093084461006581b776c2ef1b960ee946a5eaf42f175cd9aace8fd1a",
                  "action":"send",
                  "message":"0",
                  "token":"AXNT",
                  "prev_hash":"0",
                  "timestamp":1615927723068,
                  "scaled":1,
                  "kind":"FAST",
                  "version":"V1",
                  "senders":[
                     {
                        "address":"VDAyNThiOWFiN2Q5YWM3ZjUyYTNhYzQwZTY1NDBmYWJkMjczZmVmZThlOTgzMWM4",
                        "public_key":"8b3c61787fb6b07bb20e4a908deca52ef96335e4faaaaca18a227f9d674dcc57",
                        "amount":2000,
                        "fee":1000,
                        "signature":"0"
                     },
                     {
                        "address":"VDBiYjkyMjY1ZDJlOTNkZmNjN2NmYWFhZTVhMzVlYjZmYjY2YzllNWFjYWY3N2Nh",
                        "public_key":"cd79aa3b76078fb6dbe8199fccbc49a7e0deadbc9370791180e34dbabd65a47e",
                        "amount":5000,
                        "fee":1000,
                        "signature":"0"
                     }
                  ],
                  "recipients":[
                     {
                        "address":"VDA4M2YwYTkzZTQxZTQ0NzdjOGRjMDU4ZTkwZTI4OWY1NDNkMDZjYmU3ODQyM2Rk",
                        "amount":2000
                     },
                     {
                        "address":"VDAwZDRiYTg0MWVlZjE4M2U3OWY2N2E0YmZkZDJjN2JmMWE0ZTViMjE3ZDNmZTU1",
                        "amount":3000
                     }
                  ]
               },
               {
                  "id":".32b2dbcd7b7494cffb89cb7f8bd188bf4c496da965332e7b08328d4e63442856",
                  "action":"send",
                  "message":"0",
                  "token":"AXNT",
                  "prev_hash":"0",
                  "timestamp":1615971474028,
                  "scaled":1,
                  "kind":"FAST",
                  "version":"V1",
                  "senders":[
                     {
                        "address":"VDAyNThiOWFiN2Q5YWM3ZjUyYTNhYzQwZTY1NDBmYWJkMjczZmVmZThlOTgzMWM4",
                        "public_key":"8b3c61787fb6b07bb20e4a908deca52ef96335e4faaaaca18a227f9d674dcc57",
                        "amount":2000,
                        "fee":3000,
                        "signature":"0"
                     },
                     {
                        "address":"VDBiYjkyMjY1ZDJlOTNkZmNjN2NmYWFhZTVhMzVlYjZmYjY2YzllNWFjYWY3N2Nh",
                        "public_key":"cd79aa3b76078fb6dbe8199fccbc49a7e0deadbc9370791180e34dbabd65a47e",
                        "amount":7000,
                        "fee":1000,
                        "signature":"0"
                     }
                  ],
                  "recipients":[
                     {
                        "address":"VDA4M2YwYTkzZTQxZTQ0NzdjOGRjMDU4ZTkwZTI4OWY1NDNkMDZjYmU3ODQyM2Rk",
                        "amount":2000
                     },
                     {
                        "address":"VDAwZDRiYTg0MWVlZjE4M2U3OWY2N2E0YmZkZDJjN2JmMWE0ZTViMjE3ZDNmZTU1",
                        "amount":3000
                     }
                  ]
               }
            ]
         }
        }.gsub(/\s+/,"")
      hashable_block.to_json.should eq(expected_json)  
  end
end

def transaction_1
  id = "be8473ea093084461006581b776c2ef1b960ee946a5eaf42f175cd9aace8fd1a"
  timestamp = 1615927723068_i64

  senders = [
    Sender.new(
      "VDAyNThiOWFiN2Q5YWM3ZjUyYTNhYzQwZTY1NDBmYWJkMjczZmVmZThlOTgzMWM4",
      "8b3c61787fb6b07bb20e4a908deca52ef96335e4faaaaca18a227f9d674dcc57",
      2000_i64,
      1000_i64,
      "0"
    ),
    Sender.new(
      "VDBiYjkyMjY1ZDJlOTNkZmNjN2NmYWFhZTVhMzVlYjZmYjY2YzllNWFjYWY3N2Nh",
      "cd79aa3b76078fb6dbe8199fccbc49a7e0deadbc9370791180e34dbabd65a47e",
      5000_i64,
      1000_i64,
      "0"
    ),
  ]
  recipients = [
    Recipient.new("VDA4M2YwYTkzZTQxZTQ0NzdjOGRjMDU4ZTkwZTI4OWY1NDNkMDZjYmU3ODQyM2Rk", 2000_i64),
    Recipient.new("VDAwZDRiYTg0MWVlZjE4M2U3OWY2N2E0YmZkZDJjN2JmMWE0ZTViMjE3ZDNmZTU1", 3000_i64),
  ]
  Transaction.new(id, "send", senders, recipients, "0", "AXNT", "0", timestamp, 1, TransactionKind::FAST, TransactionVersion::V1)
end

def transaction_2
  id = ".32b2dbcd7b7494cffb89cb7f8bd188bf4c496da965332e7b08328d4e63442856"
  timestamp = 1615971474028_i64

  senders = [
    Sender.new(
      "VDAyNThiOWFiN2Q5YWM3ZjUyYTNhYzQwZTY1NDBmYWJkMjczZmVmZThlOTgzMWM4",
      "8b3c61787fb6b07bb20e4a908deca52ef96335e4faaaaca18a227f9d674dcc57",
      2000_i64,
      3000_i64,
      "0"
    ),
    Sender.new(
      "VDBiYjkyMjY1ZDJlOTNkZmNjN2NmYWFhZTVhMzVlYjZmYjY2YzllNWFjYWY3N2Nh",
      "cd79aa3b76078fb6dbe8199fccbc49a7e0deadbc9370791180e34dbabd65a47e",
      7000_i64,
      1000_i64,
      "0"
    ),
  ]
  recipients = [
    Recipient.new("VDA4M2YwYTkzZTQxZTQ0NzdjOGRjMDU4ZTkwZTI4OWY1NDNkMDZjYmU3ODQyM2Rk", 2000_i64),
    Recipient.new("VDAwZDRiYTg0MWVlZjE4M2U3OWY2N2E0YmZkZDJjN2JmMWE0ZTViMjE3ZDNmZTU1", 3000_i64),
  ]
  Transaction.new(id, "send", senders, recipients, "0", "AXNT", "0", timestamp, 1, TransactionKind::FAST, TransactionVersion::V1)
end
