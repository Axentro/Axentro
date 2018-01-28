module ::Sushi::Core::Models
  alias Header = NamedTuple(
    index: Int64,
    nonce: UInt64,
    prev_hash: String,
    merkle_tree_root: String,
  )
end
