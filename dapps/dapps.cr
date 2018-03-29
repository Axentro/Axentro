module ::Sushi::Core::DApps::User
  #
  # todo: fix here
  # If you want to activate 'CreateTransaction' sample app,
  # fix here like this.
  # ```
  # USER_APPS = %w(HelloWorld CreateTransaction)
  # ```
  #
  # The CreateTransaction sample is hosted by `wallets/testnet-0.json`,
  # so you have to specify the wallet when you launch a node.
  #
  USER_DAPPS = %w()

  {% for dapp in USER_DAPPS %}
    @{{ dapp.id.underscore }} : {{ dapp.id }}?

    def {{ dapp.id.underscore }} : {{ dapp.id }}
      @{{ dapp.id.underscore }}.not_nil!
    end
  {% end %}
end

require "./*"
