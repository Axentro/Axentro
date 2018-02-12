module ::Units::Utils::WalletHelper
  include Sushi::Core

  def wallet_1
    json = %{
      {
        "private_key": "dc671bbcbcf7aadfcc88dd32de9717f3ccf973b420b7d2eae1f1ff95d9f3ab8a",
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
        "private_key": "39d5ce7c30f53edcb6c0705bae83b217385e7bed0505b7336cbaee35492569ba",
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
        "private_key": "70ccf5e6156f89f2c4056f991677f769a87da62257af92c0bae55e1237196d4c",
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
        "private_key": "394961c3cfac21900f12c71200f87b5507eb0c31e57a52d2c8fa8d75b2ac40f3",
        "public_key": "6cf7906f619afb1a9f7ff91c087a985d69f26ab7b50d74588a3bdb66df6ee32d65ca181294a1dc89f138ba60ab4dce09fea687e1e06a9a5f1c66e86817f2cf5e",
        "wif": "VDAzOTQ5NjFjM2NmYWMyMTkwMGYxMmM3MTIwMGY4N2I1NTA3ZWIwYzMxZTU3YTUyZDJjOGZhOGQ3NWIyYWM0MGYzMWM3Mzdi",
        "address": "VDA3Nzk2MDQxMmIwNDU0NDcxNDJkMTlkYWQ0ZDRjYWVlOTA2ZTgzZTY4YmZjZDYy"
      }
    }
    Wallet.from_json(json)
  end
end
