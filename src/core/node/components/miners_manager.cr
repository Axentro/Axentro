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

  class Miner
    property socket : HTTP::WebSocket
    property mid : String
    property difficulty : Int32
    def initialize(@socket, @mid, @difficulty); end
  end

  class NonceMeta
    property difficulty : Int32
    property deviance : Int64
    def initialize(@difficulty, @deviance); end
  end

  class MinersManager < HandleSocket
    include NonceModels

    alias Miners = Array(Miner)

    @most_difficult_block_so_far : SlowBlock
    @block_start_time : Int64
    @nonce_meta_map : Hash(String,Array(NonceMeta)) = {} of String => Array(NonceMeta)

    getter miners : Miners = Miners.new

    def initialize(@blockchain : Blockchain, @is_private_node : Bool)
      @highest_difficulty_mined_so_far = 0
      @block_start_time = __timestamp
      @most_difficult_block_so_far = @blockchain.genesis_block
    end

    def handshake(socket, context, _content)
      return unless node.phase == SetupPhase::DONE

      verbose "requested handshake from a miner"

      _m_content = MContentMinerHandshake.from_json(_content)

      version = _m_content.version
      address = _m_content.address
      mid = _m_content.mid

      if Core::CORE_VERSION > version
        return send(socket,
          M_TYPE_MINER_HANDSHAKE_REJECTED,
          {
            reason: "your miner is out of date, please update it" +
                    "(node version: #{Core::CORE_VERSION}, miner version: #{version})",
          })
      end

      if miners.size >= @blockchain.max_miners
        return send(socket,
          M_TYPE_MINER_HANDSHAKE_REJECTED,
          {
            reason: "The max number of miners allowed to connect to this node has been reached (#{@blockchain.max_miners})",
          })
      end

      if @is_private_node
        return send(socket,
          M_TYPE_MINER_HANDSHAKE_REJECTED,
          {
            reason: "Mining against private nodes is not supported",
          })
      end

      miner_network = Wallet.address_network_type(address)[:name]

      if miner_network != node.network_type
        warning "mismatch network type with miner #{address}"

        return send(socket, M_TYPE_MINER_HANDSHAKE_REJECTED, {
          reason: "network type mismatch",
        })
      end

      miner = Miner.new(socket, mid, @blockchain.mining_block_difficulty_miner)

      @miners << miner

      @nonce_meta_map[miner.mid] = [NonceMeta.new(17, 0_i64)]

      remote_address = context.try(&.request.remote_address.to_s) || "unknown"
      miner_name = HumanHash.humanize(mid)
      info "new miner (#{remote_address}) : #{light_green(miner_name)} (#{@miners.size})"

      send(socket, M_TYPE_MINER_HANDSHAKE_ACCEPTED, {
        version:    Core::CORE_VERSION,
        block:      @blockchain.mining_block,
        difficulty: @blockchain.mining_block_difficulty_miner,
      })

      spawn do
      loop do
         sleep 20
        puts "MINER CHECK"
        @miners.each do |miner|
          puts "In miner"
          existing_miner_nonces = MinerNoncePool.find_by_mid(miner.mid)
          if existing_miner_nonces.size > 0
            
            nonce_meta = @nonce_meta_map[miner.mid]
            last_difficulty = miner.difficulty
            deviance = __timestamp - existing_miner_nonces.last.timestamp

            if deviance > 10000
              last_difficulty = miner.difficulty
              miner.difficulty = Math.max(1, miner.difficulty - 1)
              if last_difficulty != miner.difficulty
                info "(check) decreased difficulty to #{miner.difficulty} for deviance: #{deviance}"
                send_updated_block(miner.socket, miner.difficulty)
              end
            else
              last_difficulty = miner.difficulty
              miner.difficulty = Math.max(1, miner.difficulty + 1)
              if last_difficulty != miner.difficulty
                info "(check) increased difficulty to #{miner.difficulty} for deviance: #{deviance}"
                send_updated_block(miner.socket, miner.difficulty)
              end
            end
          else
            #no nonces found within 10 secs so decrease difficulty
            miner.difficulty = Math.max(1, miner.difficulty - 1)
            info "(check) decrease difficulty to #{miner.difficulty} as no nonces found within 10 seconds"
            send_updated_block(miner.socket, miner.difficulty)
          end
      end
      end
    end
    end

    def found_nonce(socket, _content)
      # 1. should return a message to the miner to say the node was not ready to accept nonces yet
      return unless node.phase == SetupPhase::DONE

      # 2. when we receive a nonce from a miner it should have a mid, nonce, valid timestamp, valid addres
      # so we should validate those here and return a message to the miner if nonce rejected because of invalid data
      # we should validate here if already found nonce and if timestamp falls within correct parameters
    
      # getter mid : String = "0"
      # getter value : BlockNonce
      # getter timestamp : Int64 = 0_i64
      # getter address : String = "0"
      # getter node_id : String = "0"

      # 3. process nonce data from miner
      _m_content = MContentMinerFoundNonce.from_json(_content)

      miner_nonce = _m_content.nonce
      mined_timestamp = miner_nonce.timestamp
      miner_difficulty = miner_nonce.difficulty

      arriving_block = @blockchain.mining_block.with_nonce(miner_nonce.value)
      arriving_block_hash = arriving_block.to_hash
      mined_difficulty = arriving_block.valid_nonce_for_difficulty(arriving_block_hash, miner_nonce.value, miner_difficulty)

      info "received a nonce of #{miner_nonce.value}, difficulty #{miner_difficulty}, result: #{mined_difficulty}, timestamp #{mined_timestamp}, hash: #{arriving_block_hash}"
  
    
      
      # 4. find miner socket 
      if miner = find?(socket)
        # 5. update mining block with nonce from miner
        # arriving_block = @blockchain.mining_block.with_nonce(miner_nonce.value)
        # mined_difficulty = arriving_block.valid_nonce_for_difficulty(arriving_block.to_hash, miner_nonce.value, miner.difficulty)
        block = arriving_block.with_difficulty(miner.difficulty)

        # 6. check difficulty is valid
        # puts "HASH: #{block.to_hash} , nonce: #{miner_nonce.value}, difficulty: #{miner.difficulty}"
        # pp block
        
        if mined_difficulty < @blockchain.mining_block_difficulty_miner
          # if not valid - resend latest mining block
          error "mined difficulty for nonce: #{miner_nonce.value} is: #{mined_difficulty} and expected is: #{@blockchain.mining_block_difficulty_miner}"
          # error "received nonce is invalid, try to update latest block"
          # send_updated_block(miner.socket, miner.difficulty)
        else
          # if valid - continue processing
          # add nonce to pool         
          miner_nonce = miner_nonce.with_node_id(node.get_node_id).with_mid(miner.mid)
          @blockchain.add_miner_nonce(miner_nonce)

          miner_name = HumanHash.humanize(miner.mid)
          nonces_size = @blockchain.miner_nonce_pool.find_by_mid(miner.mid).size
          debug "miner #{miner_name} found nonce at timestamp #{mined_timestamp}.. (nonces: #{nonces_size}) mined with difficulty #{mined_difficulty} "
          
          # find last nonce the miner sent
          existing_miner_nonces = MinerNoncePool.find_by_mid(miner.mid)
          if existing_miner_nonces.size > 0
            last_miner_nonce = existing_miner_nonces.sort_by{|mn| mn.timestamp }.reverse
            time_difference = mined_timestamp - last_miner_nonce.first.timestamp
            
            # add the nonce to the historic tracking
            @nonce_meta_map[miner.mid] << NonceMeta.new(miner.difficulty, time_difference)
            
            nonce_meta = @nonce_meta_map[miner.mid]
            average_deviance = (nonce_meta.map(&.deviance).sum / nonce_meta.size).to_i
            average_difficulty = (nonce_meta.map(&.difficulty).sum / nonce_meta.size).to_i

            if average_deviance > 10000
              # if the last nonce the miner sent was more than 10 seconds ago since last nonce - decrease difficulty - resend block
              last_difficulty = miner.difficulty
              miner.difficulty = Math.max(1, average_difficulty - 1)
              if last_difficulty != miner.difficulty
                info "(found_nonce) decrease difficulty to #{miner.difficulty} for deviance: #{average_deviance}"
                send_updated_block(miner.socket, miner.difficulty)
              end
            else
              # if the last nonce the miner sent was less than 10 seconds ago since last nonce - increase difficulty - resend block
              last_difficulty = miner.difficulty
              miner.difficulty = Math.max(1, average_difficulty + 1)
              if last_difficulty != miner.difficulty
                info "(found_nonce) increased difficulty to #{miner.difficulty} for deviance: #{average_deviance}"
                send_updated_block(miner.socket, miner.difficulty) 
              end
            end


            # if time_difference > 1000
            #   # if the last nonce the miner sent was more than 10 seconds ago since last nonce - decrease difficulty - resend block
            #   miner.difficulty = Math.max(1, miner.difficulty - 1)
            #   decreased = miner.difficulty
            #   info "(found_nonce) decrease difficulty to #{decreased} for deviance: #{time_difference}"
            #   send_updated_block(miner.socket, decreased)
            # else
            #    # if the last nonce the miner sent was less than 10 seconds ago since last nonce - increase difficulty - resend block
            #    miner.difficulty = Math.max(1, miner.difficulty + 2)
            #    increased = miner.difficulty
            #   info "(found_nonce) increased difficulty to #{increased} for deviance: #{time_difference}"
            #   send_updated_block(mi@miner_difficulty_map[miner.mid] ner.socket, increased)
            # end       
            # if the last nonce the miner sent was exactly 10 seconds ago since last nonce - same difficulty - nothing to do  
          end

          debug "found nonce of #{block.nonce} that doesn't satisfy block difficulty, checking if it is the best so far"
          current_miner_difficulty = block_difficulty_to_miner_difficulty(@blockchain.mining_block_difficulty)
          if (mined_difficulty > current_miner_difficulty) && (mined_difficulty > @highest_difficulty_mined_so_far)
            debug "This block is now the most difficult recorded"
            @most_difficult_block_so_far = block.dup
            @highest_difficulty_mined_so_far = mined_difficulty
          else
            debug "This block was not the most difficult recorded, miner still gets credit for sending the nonce"
          end
          if mined_timestamp > @block_start_time + (Consensus::POW_TARGET_SPACING * 0.90).to_i32
            if @highest_difficulty_mined_so_far > 0
              debug "Time has expired for block #{block.index} ... the block with the most difficult nonce recorded so far will be minted: #{@highest_difficulty_mined_so_far}"
              @most_difficult_block_so_far.to_s
              mint_block(@most_difficult_block_so_far)
            else
              debug "Time has expired for block #{block.index} ... but no nonce with a difficulty larger than miner difficulty (#{current_miner_difficulty}) has been received.. keep waiting"
            end
          end

        end
      end

    end

    def send_updated_block(socket, difficulty : Int32)
      send(socket, M_TYPE_MINER_BLOCK_UPDATE, {
        block:      @blockchain.mining_block,
        difficulty: difficulty,
      })
    end

    # def found_nonce2(socket, _content)
    #   return unless node.phase == SetupPhase::DONE

    #   verbose "miner sent a new nonce"

    #   _m_content = MContentMinerFoundNonce.from_json(_content)

    #   miner_nonce = _m_content.nonce
    #   mined_timestamp = miner_nonce.timestamp
    #   debug "received a nonce of #{miner_nonce.value} from a miner at timestamp #{mined_timestamp}"

    #   if miner = find?(socket)
    #     block = @blockchain.mining_block.with_nonce(miner_nonce.value)

    #     if ENV.has_key?("AX_SET_DIFFICULTY")
    #       mint_block(block)
    #       return
    #     end

    #     debug "Received a freshly mined block..."
    #     block.to_s

    #     if @blockchain.miner_nonce_pool.find(miner_nonce)
    #       warning "nonce #{miner_nonce.value} has already been discovered"
    #       return
    #     end

    #     if mined_timestamp < @blockchain.mining_block.timestamp
    #       warning "received nonce was mined before current mining block was created, ignore"
    #       return
    #     end

    #     mined_difficulty = block.valid_nonce?(@blockchain.mining_block_difficulty)
    #     if mined_difficulty < @blockchain.mining_block_difficulty_miner
    #       info "mined difficulty is: #{mined_difficulty} and expected is: #{@blockchain.mining_block_difficulty_miner}"

    #       warning "received nonce is invalid, try to update latest block"
    #       debug "mined difficulty is: #{mined_difficulty}"

    #       send(miner[:socket], M_TYPE_MINER_BLOCK_UPDATE, {
    #         block:      @blockchain.mining_block,
    #         difficulty: @blockchain.mining_block_difficulty_miner,
    #       })
    #     else
    #       miner_name = HumanHash.humanize(miner[:mid])
    #       nonces_size = @blockchain.miner_nonce_pool.find_by_mid(miner[:mid]).size
    #       debug "miner #{miner_name} found nonce at timestamp #{mined_timestamp}.. (nonces: #{nonces_size}) mined with difficulty #{mined_difficulty} "

    #       # add nonce to pool - maybe batch instead of sending one nonce at a time?
    #       miner_nonce = miner_nonce.with_node_id(node.get_node_id).with_mid(miner[:mid])
    #       @blockchain.add_miner_nonce(miner_nonce)
    #       node.send_miner_nonce(miner_nonce)

    #       debug "found nonce of #{block.nonce} that doesn't satisfy block difficulty, checking if it is the best so far"
    #       current_miner_difficulty = block_difficulty_to_miner_difficulty(@blockchain.mining_block_difficulty)
    #       if (mined_difficulty > current_miner_difficulty) && (mined_difficulty > @highest_difficulty_mined_so_far)
    #         debug "This block is now the most difficult recorded"
    #         @most_difficult_block_so_far = block.dup
    #         @highest_difficulty_mined_so_far = mined_difficulty
    #       else
    #         debug "This block was not the most difficult recorded, miner still gets credit for sending the nonce"
    #       end
    #       if mined_timestamp > @block_start_time + (Consensus::POW_TARGET_SPACING * 0.90).to_i32
    #         if @highest_difficulty_mined_so_far > 0
    #           debug "Time has expired for block #{block.index} ... the block with the most difficult nonce recorded so far will be minted: #{@highest_difficulty_mined_so_far}"
    #           @most_difficult_block_so_far.to_s
    #           mint_block(@most_difficult_block_so_far)
    #         else
    #           debug "Time has expired for block #{block.index} ... but no nonce with a difficulty larger than miner difficulty (#{current_miner_difficulty}) has been received.. keep waiting"
    #         end
    #       end
    #     end
    #   end
    # end

    def mint_block(block : SlowBlock)
      @highest_difficulty_mined_so_far = 0
      @block_start_time = __timestamp
      node.new_block(block)
      node.send_block(block)
    end

    def forget_most_difficult
      debug "Forgetting most difficult"
      @highest_difficulty_mined_so_far = 0
      @block_start_time = __timestamp
    end

    def broadcast
      info "#{magenta("PREPARING NEXT SLOW BLOCK")}: #{light_green(@blockchain.mining_block.index)} at difficulty: #{light_cyan(@blockchain.mining_block_difficulty)}"
      debug "new block difficulty: #{@blockchain.mining_block_difficulty}, " +
            "mining difficulty: #{@blockchain.mining_block_difficulty_miner}"

      @miners.each do |miner|
        send(miner.socket, M_TYPE_MINER_BLOCK_UPDATE, {
          block:      @blockchain.mining_block,
          difficulty: @blockchain.mining_block_difficulty_miner,
        })
      end
    end

    def find?(socket : HTTP::WebSocket) : Miner?
      @miners.find { |m| m.socket == socket }
    end

    def clean_connection(socket)
      current_size = @miners.size
      @miners.reject! { |miner| miner.socket == socket }

      info "a miner has been removed. (#{current_size} -> #{@miners.size})" if current_size > @miners.size
    end

    def size
      @miners.size
    end

    private def node
      @blockchain.node
    end

    include Protocol
    include Consensus
    include Common::Color
  end
end
