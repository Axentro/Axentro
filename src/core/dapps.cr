require "./*"
require "./dapps/dapp"

module ::Sushi::Core::DApps
  getter dapps : Array(DApp) = [] of DApp

  def setup_dapps
    {% for dapp in BUILD_IN_DAPPS %}
      @{{ dapp.id.underscore }} = {{ dapp.id }}.new(self)
      @dapps.push(@{{ dapp.id.underscore }}.not_nil!)
    {% end %}

    {% for dapp in USER_DAPPS %}
      @{{ dapp.id.underscore }} = {{ dapp.id }}.new(self)
      @dapps.push(@{{ dapp.id.underscore }}.not_nil!)
    {% end %}
  end

  include BuildIn
  include User
end
