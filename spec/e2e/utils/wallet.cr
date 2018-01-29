module ::E2E::Utils::Wallet
  def wallet(num : Int32) : String
    File.expand_path("../../../../wallets/testnet-#{num}.json", __FILE__)
  end
end
