module ::Sushi::Core
  abstract class DApp
    abstract def valid?(transaction : Transaction, prev_transactions : Array(Transaction)) : Bool
    abstract def record(chain : Models::Chain)
    abstract def clear
  end
end

require "./*"
require "./dapps/*"
