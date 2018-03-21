require "./build_in/*"

module ::Sushi::Core::DApps::BuildIn
  BUILD_IN_DAPPS = %w(BlockchainInfo UTXO Scars Indices Rejects)

  {% for dapp in BUILD_IN_DAPPS %}
    @{{ dapp.id.underscore }} : {{ dapp.id }}?

    def {{ dapp.id.underscore }} : {{ dapp.id }}
      @{{ dapp.id.underscore }}.not_nil!
    end
  {% end %}
end
