require 'rubygems'
require 'mqtt'
require 'json'

require_relative 'folloger_client_base'

module Folloger
  class MQTTClient < Base
    def initialize(host = "127.0.0.1", port = 1883, args = {})
      set_location(host, port)
      set_timeout(120)
      set_retry(MAX_RETRY)
      @client_id = MQTT::Client.generate_client_id
      if ( args[:user] )
        @client = MQTT::Client.connect(remote_host: @host,
                                       remote_port: @port,
                                       client_id:  @client_id,
                                       username: args[:user],
                                       password: args[:pass])
      else
        @client = MQTT::Client.connect(remote_host: @host,
                                       remote_port: @port,
                                       client_id:  @client_id)
      end
    end
    def put_data(uuid, data, params = {})
      print [ params[:session_id], data].to_json, "\n"
      print [ params[:session_id], data].to_json.length, "\n"
      @client.publish("#{uuid}/json", [ params[:session_id], data].to_json,
                      params[:retain], params[:qos])
    end
    def auth_user(user, pass)
      if ( !@client )
        @client_id = MQTT::Client.generate_client_id
        @client = MQTT::Client.connect(remote_host: @host,
                                       remote_port: @port,
                                       client_id:  @client_id,
                                       username: user,
                                       password: pass)
        if ( @client )
          @user = user
          @pass = pass
        else
          @client_id = nil
        end
      end
      @client_id
    end
    def last_at(uuid, params = {})
      nil
    end
    def method_missing(name, *args)
      nil
    end
  end
end
