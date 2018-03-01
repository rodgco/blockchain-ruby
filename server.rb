require './blockchain'
require 'sinatra'
require 'json'
require './json_ext'
require 'securerandom'

blockchain = Blockchain.new

node_identifier = SecureRandom.uuid.gsub('-', '')

get '/mine' do
    last_block = blockchain.last_block
    last_proof = last_block[:proof]
    proof = blockchain.proof_of_work(last_proof)

    # We must receive a reward for finding the proof.
    # The sender is "0" to signify that this node has mined a new coin.
    blockchain.new_transaction(
        sender="0",
        recipient=node_identifier,
        amount=1
    )

    # Forge the new Block by adding it to the chain
    block = blockchain.new_block(proof)

    response = {
        :message => "New Block Forged",
        :index => block[:index],
        :transactions => block[:transactions],
        :proof => block[:proof],
        :previous_hash => block[:previous_hash]
    }
    status 200
    body response.to_json
end

post '/transactions/new' do

    # Check validity of JSON was POST'ed
    request.body.rewind
    request_body = request.body.read
    
    if !JSON.valid?(request_body) then
        status 400
        response = { :message => "Error: Please supply a valid JSON" }
        body response.to_json
        return 
    end

    values = JSON.parse(request_body)

    # Check that the required fields are in the POST'ed data
    required = ['sender', 'recipient', 'amount']

    if !required.all? {|s| values.key? s} then
        status 400
        response = { :message => 'Error: Missing values' }
        body response.to_json
        return
    end

    # Create a new Transaction
    index = blockchain.new_transaction(values['sender'], values['recipient'], values['amount'])

    response = { :message => "Transaction will be added to Block #{index}" }
    
    status 201
    body response.to_json
end

get '/chain' do
    response = {
        :chain => blockchain.chain,
        :length => blockchain.chain.size
    }

    status 200
    body response.to_json
end

post '/nodes/register' do
    request.body.rewind
    request_body = request.body.read

    if !JSON.valid?(request_body) then
        status 400
        body "Error: Please supply a valid JSON"
        return 
    end

    values = JSON.parse(request_body)
    
    nodes = values["nodes"]
    
    if !nodes then
        status 400
        body "Error: Please supply a valid list of nodes"
        return
    end

    nodes.each do |node|
        blockchain.register_node(node)
    end

    response = { :message => 'New nodes have been added', :total_nodes => blockchain.nodes }

    status 201
    body response.to_json
end

get '/nodes/resolve' do
    replaced = blockchain.resolve_conflicts

    if replaced then
        response = { message: 'Our chain was replaced', new_chain: blockchain.chain }
    else
        response = { message: 'Our chain is authoritative', chain: blockchain.chain }
    end

    status 200
    body response.to_json
end
