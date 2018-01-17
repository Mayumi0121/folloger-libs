require 'rubygems'

$LOAD_PATH << "./libs"
require 'batch'

require_relative 'memory_size_checker'
require_relative 'env'

class Notificator < Batch::Base
  def run
    CHECK_STREAMS.each do | check_stream |
      checker = Checkers.const_get(check_stream[:checker]).new(check_stream[:uuid], check_stream[:param])
      checker.send_notification
    end
  end
end

Notificator.run()
