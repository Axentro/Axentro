module ::Garnet::Core::Models
  alias Header = NamedTuple(
          index: UInt32,
          nonce: UInt64,
          prev_hash: String,
          merkle_tree_root: String,
        )
end
