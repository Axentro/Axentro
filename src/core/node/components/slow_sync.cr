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
  end

  struct RejectBlock
    include JSON::Serializable
    property reason : RejectBlockReason
    property rejected : Block
    property latest : Block
    property same : Block?

    def initialize(@reason, @rejected, @latest, @same); end
  end

  class SlowSync
    def initialize(@incoming_block : Block, @mining_block : Block, @has_block : Block?, @latest_slow : Block); end

    def process : SlowSyncState
      if @has_block
        already_in_db(@has_block.not_nil!.as(Block))
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
          # incoming is behind next in sequence (can ignore this block)
          SlowSyncState::REJECT_VERY_OLD
        end
      end
    end

    private def already_in_db(existing_block : Block)
      # if incoming block latest in sequence
      if @incoming_block.index == @latest_slow.index
        if @incoming_block.difficulty > existing_block.difficulty
          # incoming block has higher difficulty than our (take theirs)
          SlowSyncState::REPLACE
        elsif @incoming_block.difficulty < existing_block.difficulty
          # our block has higher difficulty than incoming one (keep ours & ignore)
          SlowSyncState::REJECT_OLD
        else
          @incoming_block.difficulty == existing_block.difficulty
          # incoming block and our block are the same difficulty - choose by earliest timestamp
          if @incoming_block.timestamp < existing_block.timestamp
            # incoming block is earlier then ours (take theirs)
            SlowSyncState::REPLACE
          elsif @incoming_block.timestamp > existing_block.timestamp
            # incoming block is not as early as ours (keep ours & ignore)
            SlowSyncState::REJECT_OLD
          else
            # incoming block is exactly the same timestamp - check the hashes
            if @incoming_block.to_hash == existing_block.to_hash
              # keep ours as it's identical
              SlowSyncState::REJECT_OLD
            else
              # take theirs (more stable)
              SlowSyncState::REPLACE
            end
          end
        end
      else
        # if incoming block is not latest in sequence
        if @incoming_block.index > @latest_slow.index
          # incoming block is ahead of our latest
          SlowSyncState::SYNC
        else
          # incoming block is behind our latest (can ignore this block)
          SlowSyncState::REJECT_VERY_OLD
        end
      end
    end
  end
end
