require 'json'

module Nexmo
  module JSON
    def self.update(http_request, params)
      http_request['Content-Type'] = 'application/json'
      http_request.body = ::JSON.generate(params)
    end
  end
end
