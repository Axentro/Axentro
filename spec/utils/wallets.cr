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

module ::Units::Utils::WalletHelper
  include Axentro::Core

  def wallet_1
    json = %{
      {
        "public_key": "3187df5c25122c1130eec19fabc1725766b99ded9fa64659ed83d5c281c3fa3a25c1ca2c39ddda144351de2dda6c22be66194e1d1343d67578d3174a3927d24e",
        "wif": "VDBkYzY3MWJiY2JjZjdhYWRmY2M4OGRkMzJkZTk3MTdmM2NjZjk3M2I0MjBiN2QyZWFlMWYxZmY5NWQ5ZjNhYjhhMTRmN2M4",
        "address": "VDBkNTczOGQ1NmIzNmYwN2Y0Y2M1NzU0YWNiOTZkMGZkYWIwOWJiZjlhZjFiNjZk"
      }
    }
    Wallet.from_json(json)
  end

  def wallet_2
    json = %{
      {
        "public_key": "cbd2ed72620eb3dcfee6162071222cd118a832e32f5ba7eeff84d0347a2fc7687220bff8860daa5adaf8a408ef6c75ea5276c94f2c51d5973701eac9cec51129",
        "wif": "VDAzOWQ1Y2U3YzMwZjUzZWRjYjZjMDcwNWJhZTgzYjIxNzM4NWU3YmVkMDUwNWI3MzM2Y2JhZWUzNTQ5MjU2OWJhZmY1MzQy",
        "address": "VDA1OGIyNWFiZDI2OTAyM2RjOTQyNzEzNmM2YTAzZGRjNTlkYzJiNjVjNTIxYTc3"
      }
    }
    Wallet.from_json(json)
  end

  def wallet_3
    json = %{
      {
        "public_key": "cc965ccffe85216766cf95e3293942271a27d2b63b6a2af7b136db5c5e13223ee2cca22ddf2ec4993dc659c2458480cb5c4673e3bf8e68a6adec60913aa15bbd",
        "wif": "VDA3MGNjZjVlNjE1NmY4OWYyYzQwNTZmOTkxNjc3Zjc2OWE4N2RhNjIyNTdhZjkyYzBiYWU1NWUxMjM3MTk2ZDRjYjA3MmZl",
        "address": "VDA2NjI3ODViYWYyZDJlNzhhM2EyMDAxMzI0MDg2YjE5MTBjY2Q3MjAyZTU2OTdm"
      }
    }
    Wallet.from_json(json)
  end

  def wallet_4
    json = %{
      {
        "public_key": "6cf7906f619afb1a9f7ff91c087a985d69f26ab7b50d74588a3bdb66df6ee32d65ca181294a1dc89f138ba60ab4dce09fea687e1e06a9a5f1c66e86817f2cf5e",
        "wif": "VDAzOTQ5NjFjM2NmYWMyMTkwMGYxMmM3MTIwMGY4N2I1NTA3ZWIwYzMxZTU3YTUyZDJjOGZhOGQ3NWIyYWM0MGYzMWM3Mzdi",
        "address": "VDA3Nzk2MDQxMmIwNDU0NDcxNDJkMTlkYWQ0ZDRjYWVlOTA2ZTgzZTY4YmZjZDYy"
      }
    }
    Wallet.from_json(json)
  end
end
