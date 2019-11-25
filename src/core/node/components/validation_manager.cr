# Copyright © 2017-2018 The SushiChain Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the SushiChain Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

module ::Sushi::Core::NodeComponents
  class ValidationManager < HandleSocket

    alias ValidatingNode = NamedTuple(
      host: String,
      port: Int32,
      validating_hash: String,
    )

    alias ValidatingNodes = Array(ValidatingNode)

    @nodes_awaiting_validation = ValidatingNodes.new

    def initialize(
      @blockchain : Blockchain,
      @bind_host : String?,
      @bind_port : Int32?,
      @use_ssl : Bool
    )
    end

    def clean_connection(socket : HTTP::WebSocket)
    end

    # sends request from a newly connecting node - contains max block IDs (slow/fast) from the local DB of the connecting node
    def send_validation_request(node : Node, connect_host : String, connect_port : Int32, max_slow_block_id : Int64, max_fast_block_id : Int64)
      debug "requesting validation from: #{@bind_host}:#{@bind_port}"

      socket = HTTP::WebSocket.new(connect_host, "/peer", connect_port, @use_ssl)

      node.peer(socket)

      spawn do
        socket.run
      rescue e : Exception
        handle_exception(socket, e)
      end

      debug "Sending validation request with most recent slow (#{max_slow_block_id}) and fast (#{max_fast_block_id}) block IDs to connect node"
      send(
        socket,
        M_TYPE_VALIDATION_REQUEST,
        {
          version: Core::CORE_VERSION,
          source_host: @bind_host,
          source_port: @bind_port,
          max_slow_block_id: max_slow_block_id,
          max_fast_block_id: max_fast_block_id,
        }
      )
    rescue e : Exception
      error "failed to connect #{connect_host}:#{connect_port}"
      error "please specify another host for connection"

      node.phase = SetupPhase::PRE_DONE
      node.proceed_setup
    end

    # handles request from a newly connecting node on a running node - uses max block IDs to construct
    #  a challenge request containing an array of randome block IDs
    def validation_requested(socket, _content)
      _m_content = MContentValidationRequest.from_json(_content)

      max_slow_block_id = _m_content.max_slow_block_id
      max_fast_block_id = _m_content.max_fast_block_id
      source_host = _m_content.source_host
      source_port = _m_content.source_port

      debug "Node (#{source_host}:#{source_port}) wants database validation with slow/fast block IDs of #{max_slow_block_id}/#{max_fast_block_id}"

      random_block_list = @blockchain.get_random_block_ids(max_slow_block_id, max_fast_block_id)
      validating_hash = @blockchain.get_hash_of_block_hashes(random_block_list)
      debug "calculated hash for challenge:"
      debug "#{validating_hash}"

      @nodes_awaiting_validation.push({host: source_host, port: source_port, validating_hash: validating_hash})

      send(
        socket,
        M_TYPE_VALIDATION_CHALLENGE,
        {
          blocks_to_hash: random_block_list,
        }
      )
    rescue e : Exception
      error "failed to send validation challenge to connecting node #{source_host}:#{source_port}"
    end

    # handles challenge request in newly connecting node - challenge request contains an array of random block IDs in newly connecting node
    #  creates hash of the all of the 'prev_hash's of the blocks and sends response back with solution
    def validation_challenge_received(socket, _content)
      _m_content = MContentValidationChallenge.from_json(_content)
      random_block_list = _m_content.blocks_to_hash
      debug "size of random block list #{random_block_list.size}"
      validating_hash = @blockchain.get_hash_of_block_hashes(random_block_list)
      debug "calculated hash from challenge:"
      debug "#{validating_hash}"
      send(
        socket,
        M_TYPE_VALIDATION_CHALLENGE_RESPONSE,
        {
          source_host: @bind_host,
          source_port: @bind_port,
          solution_hash: validating_hash,
        }
      )
    rescue e : Exception
      error "failed to send validation challenge response back to connecting node"
    end

    # handles challenge response containing solution hash - if it matches the one calculated in existing node when challenge
    #  was sent, the new node is accepted, otherwise the new node fails and cannot join the SushiChain network
    def validation_challenge_response_received(socket, _content)
      debug "got into validation challenge response received"
      _m_content = MContentValidationChallengeResponse.from_json(_content)
      solution_hash = _m_content.solution_hash
      debug "solution hash received #{solution_hash}"
      found = true
      response = found ? M_TYPE_VALIDATION_SUCCEEDED : M_TYPE_VALIDATION_FAILED
      reason = found ? "match was found": "match not found"
      debug "response: #{response}"
      debug "reason: #{reason}"
      send(
        socket,
        response,
        {
          reason: reason,
        }
      )
    rescue e : Exception
      error "failed to send validation succeed/fail response back to connecting node"
    end

    # handles result message indicating success or failure of hash calculation
    def validation_challenge_result_received(node, socket, _content, message_type)
      _m_content = MContentValidationResult.from_json(_content)
      reason = _m_content.reason
      debug "reason - #{reason}"
      if message_type == M_TYPE_VALIDATION_SUCCEEDED
        debug "Validation succeeded - will attempt connection to SushiChain network"
        node.phase = SetupPhase::CONNECTING_NODES
      else
        debug "Validation failed - cannot connect to SushiChain network"
        node.phase = SetupPhase::PRE_DONE
      end
      node.proceed_setup
    end

    include Protocol

  end
end