# Copyright © 2017-2020 The Axentro Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the Axentro Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

module ::Axentro::Core::NodeComponents
  enum SlowSyncState
    CREATE
    REPLACE
    REJECT_OLD
    REJECT_VERY_OLD
    SYNC
  end

  enum RejectBlockReason
    OLD      # same index but local block is younger
    VERY_OLD # some old index
    INVALID  # invalid for some reason
  end

  struct RejectionSyncIndices
    getter slow_index : Int64
    getter fast_index : Int64

    def initialize(@slow_index, @fast_index); end
  end

  class SlowSyncReject
    def initialize(@reason : RejectBlockReason, @rejected_block : SlowBlock, @latest_remote_slow : SlowBlock, @latest_local_slow : SlowBlock, @latest_local_fast_index : Int64, @database : Database); end

    def process : RejectionSyncIndices
      # slow and fast indices have to be in sync in terms of chronological order
      slow_index = @database.lowest_slow_index_after_slow_block(@rejected_block.index) || @latest_local_slow.index
      fast_index = @database.lowest_fast_index_after_slow_block(slow_index) || @latest_local_fast_index
      RejectionSyncIndices.new(slow_index, fast_index)
    end
  end

  class SlowSync
    def initialize(@incoming_block : SlowBlock, @mining_block : SlowBlock, @database : Database, @latest_slow : SlowBlock); end

    def process : SlowSyncState
      has_block = @database.get_block(@incoming_block.index)

      if has_block
        already_in_db(has_block.not_nil!.as(SlowBlock))
      else
        not_in_db
      end
    end

    private def not_in_db
      # if incoming block next in sequence
      if @incoming_block.index == @latest_slow.index + 2
        SlowSyncState::CREATE
      else
        # if incoming block not next in sequence
        if @incoming_block.index > @latest_slow.index + 2
          # incoming is ahead of next in sequence
          SlowSyncState::SYNC
        else
          # incoming is behind next in sequence
          SlowSyncState::REJECT_VERY_OLD
        end
      end
    end

    private def already_in_db(existing_block : SlowBlock)
      # if incoming block latest in sequence
      if @incoming_block.index == @latest_slow.index
        if @incoming_block.timestamp < existing_block.timestamp
          # incoming block is earlier then ours (take theirs)
          SlowSyncState::REPLACE
        elsif @incoming_block.timestamp > existing_block.timestamp
          # incoming block is not as early as ours (keep ours & re-broadcast it)
          SlowSyncState::REJECT_OLD
        else
          SlowSyncState::REJECT_OLD
          # incoming block is exactly the same timestamp - what to do here?
        end
      else
        # if incoming block is not latest in sequence
        if @incoming_block.index > @latest_slow.index
          # incoming block is ahead of our latest
          SlowSyncState::SYNC
        else
          # incoming block is behind our latest
          SlowSyncState::REJECT_VERY_OLD
        end
      end
    end
  end
end
