require 'rubygems'
require 'uri'

module Folloger
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
end
