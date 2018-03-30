require "./*"
require "./dapps/dapp"

module ::Sushi::Core::DApps
  getter dapps : Array(DApp) = [] of DApp

  def initialize_dapps
    {% for dapp in BUILD_IN_DAPPS %}
      info "initializing {{dapp.id}}... (build in)"
      @{{ dapp.id.underscore }} = {{ dapp.id }}.new(self)
      @dapps.push(@{{ dapp.id.underscore }}.not_nil!)
    {% end %}

    {% for dapp in USER_DAPPS %}
      info "initializing {{dapp.id}}... (user)"
      @{{ dapp.id.underscore }} = {{ dapp.id }}.new(self)
      @dapps.push(@{{ dapp.id.underscore }}.not_nil!)
    {% end %}
  rescue e : Exception
    error "error happens during initializing dApps"
    error "reason:"
    error e.message.not_nil!

    exit -1
  end

  def setup_dapps
    {% for dapp in BUILD_IN_DAPPS %}
      begin
        @{{ dapp.id.underscore }}.not_nil!.setup
      rescue e : Exception
        warning "error happens during setup dApps"
        warning "reason:"
        warning e.message.not_nil!
        warning "the dApp will be removed and be ignored"

        @dapps.delete(@{{ dapp.id.underscore }}.not_nil!)
      end
    {% end %}

    {% for dapp in USER_DAPPS %}
      begin
        @{{ dapp.id.underscore }}.not_nil!.setup
      rescue e : Exception
        warning "error happens during setup dApps"
        warning "reason:"
        warning e.message.not_nil!
        warning "the dApp will be removed and be ignored"

        @dapps.delete(@{{ dapp.id.underscore }}.not_nil!)
      end
    {% end %}
  end

  include Logger
  include BuildIn
  include User
end
