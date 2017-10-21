require 'digest'
require 'json'
require 'uri'
require 'open-uri'
require 'set'

class Blockchain

    attr_accessor :chain, :nodes

    def initialize
        @current_transactions = []
        @chain = []
        @nodes = Set.new

        new_block 100, 1
    end

    def register_node(address)
        parsed_url = URI.parse(address)
        @nodes.add "#{parsed_url.host}:#{parsed_url.port}"
    end

    def valid_chain(chain)
        last_block = chain[0]
        current_index = 1

        while current_index < chain.size do
            block = chain[current_index]

            # Check that the hash of the block is correct
            if block[:previous_hash] != hash(last_block) then
                return false
            end

            # Check that the Proof of Work is correct
            if !valid_proof(last_block[:proof], block[:proof]) then
                return false
            end

            last_block = block
            current_index += 1
        end

        return true
    end

    def resolve_conflicts
        neighbours = @nodes
        new_chain = nil

        # We're only looking for chains longer than ours
        max_length = @chain.size

        # Grab and verify the chains from all the nodes in our network
        neighbours.each do |node|
            response = JSON.parse(open("http://#{node}/chain").read)
            response.deep_symbolize_keys!

            if response[:chain] then
                length = response[:length]
                chain = response[:chain]

                # Check if the length is longer and the chain is valid
                if length > max_length and valid_chain(chain) then
                    max_length = length
                    new_chain = chain
                end
            end
        end

        # Replace our chain if we discovered a new, valid chain longer than ours
        if new_chain then
            @chain = new_chain
            return true
        end

        return false
    end

    def new_block(proof, previous_hash = nil)
        block = {
            :index => @chain.size + 1,
            :timestamp => Time.now,
            :transactions => @current_transactions,
            :proof => proof,
            :previous_hash => previous_hash || hash(last_block),
        }

        # Reset the current list of transactions
        @current_transactions = []

        @chain << block
        return block
    end

    def new_transaction(sender, recipient, amount)
        @current_transactions << {
            :sender => sender,
            :recipient => recipient,
            :amount => amount,
        }

        return last_block[:index] + 1
    end

    def hash(block)
        # We must make sure that the Dictionary is Ordered, or we'll have inconsistent hashes
        block_string = block.sort.to_h.to_json
        return Digest::SHA256.hexdigest block_string
    end

    def last_block
        return @chain[-1]
    end

    def proof_of_work(last_proof)
        proof = -1
        proof += 1 until valid_proof(last_proof, proof) 
        return proof
    end

    def valid_proof(last_proof, proof)
        guess = "#{last_proof}#{proof}"
        guess_hash = Digest::SHA256.hexdigest guess
        return guess_hash[-4..-1] == "0000"
    end
end

class Hash
    def symbolize_keys!
        transform_keys!{ |key| key.to_sym rescue key }
    end

    def deep_symbolize_keys!
        deep_transform_keys!{ |key| key.to_sym rescue key }
    end

    def transform_keys!
        return enum_for(:transform_keys!) unless block_given?
        keys.each do |key|
          self[yield(key)] = delete(key)
        end
        self
    end

    def deep_transform_keys!(&block)
        _deep_transform_keys_in_object!(self, &block)
    end

    def _deep_transform_keys_in_object!(object, &block)
        case object
        when Hash
          object.keys.each do |key|
            value = object.delete(key)
            object[yield(key)] = _deep_transform_keys_in_object!(value, &block)
          end
          object
        when Array
          object.map! {|e| _deep_transform_keys_in_object!(e, &block)}
        else
          object
        end
    end
end
