module ::Sushi::Core::DApps::User
  USER_DAPPS = %w(HelloWorld)

  {% for dapp in USER_DAPPS %}
    @{{ dapp.id.underscore }} : {{ dapp.id }}?

    def {{ dapp.id.underscore }} : {{ dapp.id }}
      @{{ dapp.id.underscore }}.not_nil!
    end
  {% end %}
end

require "./*"
