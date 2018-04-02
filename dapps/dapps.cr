module ::Sushi::Core::DApps::User
  #
  # please add your dApps into the 'USER_DAPPS'
  #
  USER_DAPPS = %w(HelloWorld CreateTransaction)

  {% for dapp in USER_DAPPS %}
    @{{ dapp.id.underscore }} : {{ dapp.id }}?

    def {{ dapp.id.underscore }} : {{ dapp.id }}
      @{{ dapp.id.underscore }}.not_nil!
    end
  {% end %}
end

require "./dapp"
