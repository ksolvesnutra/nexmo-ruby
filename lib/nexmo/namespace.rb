# frozen_string_literal: true
require 'net/http'
require 'json'

module Nexmo
  class Namespace
    def initialize(client)
      @client = client

      @host = self.class.host

      @http = Net::HTTP.new(@host, Net::HTTP.https_default_port)
      @http.use_ssl = true
    end

    def self.host
      @host ||= 'api.nexmo.com'
    end

    def self.host=(host)
      @host = host
    end

    def self.authentication
      @authentication ||= KeySecretParams
    end

    def self.authentication=(authentication)
      @authentication = authentication
    end

    def self.request_body
      @request_body ||= FormData
    end

    def self.request_body=(request_body)
      @request_body = request_body
    end

    private

    Get = Net::HTTP::Get
    Put = Net::HTTP::Put
    Post = Net::HTTP::Post
    Delete = Net::HTTP::Delete

    def logger
      @client.logger
    end

    def request(path, params: nil, type: Get, &block)
      uri = URI('https://' + @host + path)

      params ||= {}

      authentication = self.class.authentication.new(@client)
      authentication.update(params)

      unless type::REQUEST_HAS_BODY || params.empty?
        uri.query = Params.encode(params)
      end

      authentication.update(uri)

      message = type.new(uri.request_uri)

      message['User-Agent'] = @client.user_agent

      authentication.update(message)

      self.class.request_body.update(message, params) if type::REQUEST_HAS_BODY

      logger.info('Nexmo API request', method: message.method, path: uri.path)

      response = @http.request(message, &block)

      log_response_info(response)

      return if block

      logger.debug(response.body)

      parse(response)
    end

    def parse(response)
      case response
      when Net::HTTPNoContent
        :no_content
      when Net::HTTPSuccess
        if response['Content-Type'].split(';').first == 'application/json'
          ::JSON.parse(response.body, object_class: Nexmo::Entity)
        else
          response
        end
      when Net::HTTPUnauthorized
        raise AuthenticationError
      when Net::HTTPClientError
        raise ClientError
      when Net::HTTPServerError
        raise ServerError
      else
        raise Error
      end
    end

    def log_response_info(response)
      logger.info('Nexmo API response',
        host: @host,
        status: response.code,
        type: response.content_type,
        length: response.content_length,
        trace_id: response['x-nexmo-trace-id'])
    end
  end
end
