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

module ::Sushi::Core::Controllers
  #
  # REST controller version 1.
  #
  # --- blockchain
  #
  # [GET] v1/blockchain                      | full blockchain
  # [GET] v1/blockchain/size                 | blockchain size
  #
  # --- block
  #
  # [GET] v1/block/{:index}                  | full block at index
  # [GET] v1/block/{:index}/header           | block header at index
  # [GET] v1/block/{:index}/transactions     | transactions in block
  #
  # --- transaction
  #
  # [GET] v1/transaction/{:id}               | transaction for supplied txn id
  # [GET] v1/transaction/{:id}/block         | full block containing txn id
  # [GET] v1/transaction/{:id}/block/header  | block header containing txn id
  # [GET] v1/transaction/{:id}/confirmation  | number confirmations for txn id
  # [GET] v1/transaction/fees                | fees
  #
  # --- address
  #
  # [GET] v1/address/{:address}/transactions | transactions for address 
  # [GET] v1/address/{:address}/confirmed    | confirmed amount for address
  # [GET] v1/address/{:address}/unconfirmed  | unconfirmed amount for address
  #
  # class RESTController < Controller
  # end
end
