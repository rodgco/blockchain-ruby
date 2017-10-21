require 'json'

module JSON
    def self.valid?(json)
        JSON.parse(json)
        return true
      rescue JSON::ParserError => e
        return false
    end
end