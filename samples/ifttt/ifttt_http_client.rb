require 'rubygems'
require 'net/http'
require 'openssl'

require 'cgi'
require 'json'

module Ifttt
  MAX_RETRY = 5
  class Base
    def set_timeout(open_timeout, read_timeout = open_timeout)
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end
    def set_retry(max_retry)
      @max_retry = max_retry
    end
  private
    def set_location(arg, port = nil)
      if ( !port )
        loc = URI.parse(arg)
        @host = loc.host
        @port = loc.port
      else
        @host = arg
        @port = port
      end
    end
  end

  class HTTPClient < Base
    def initialize(host = "127.0.0.1", port = 7001)
      set_location(host, port)
      set_timeout(120)
      set_retry(MAX_RETRY)
    end
    def put_data(event, key, data)
      _post("trigger/#{event}/with/key/#{key}", data)
    end
  private
    def _post(func, data = nil, limit = 10)
      path = "/#{func}"

      raise ArgumentError, 'HTTP redirect too deep' if limit == 0
      req = Net::HTTP::Post.new(path, {
                                  'Content-Type' => 'application/json'} )
      req.body = data.to_json
      retry_count = @max_retry

      https = Net::HTTP.new(@host, @port)
      https.use_ssl = true
      https.verify_mode = OpenSSL::SSL::VERIFY_NONE

      res = https.start do | http |
        http.open_timeout = @open_timeout
        http.read_timeout = @read_timeout
        #http.set_debug_output $stderr
        begin
          http.request(req)
        rescue TimeoutError
          raise TimeoutError, 'HTTP request timeout' if retry_count == 0
          retry_count -= 1
          http.request(req)
        end
      end
      case res
      when Net::HTTPSuccess
        if (( res.body ) &&
            ( res.body != 'null' ))
          p res.body
        else
          {
            code: -30,
            reason: "no data"
          }
        end
      when Net::HTTPRedirection
        set_location(res['location'])
        _post(func, data, limit - 1)
      else
        #p res.body
        {
          code: -30,
          reason: res.body
        }
      end
    end
  end
end
