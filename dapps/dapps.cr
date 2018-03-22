module ::Sushi::Core::DApps::User
  USER_DAPPS = %w()

  {% for dapp in USER_DAPPS %}
    @{{ dapp.id.underscore }} : {{ dapp.id }}?

    def {{ dapp.id.underscore }} : {{ dapp.id }}
      @{{ dapp.id.underscore }}.not_nil!
    end
  {% end %}
end

require "./*"
