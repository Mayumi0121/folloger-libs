# coding: utf-8
require 'rubygems'
require 'net/http'
require 'uri'
require 'cgi'
require 'json'
require 'open-uri'
require 'nokogiri'

$LOAD_PATH << "./libs"
require 'data_abstraction'
require 'folloger_client'
require 'batch'
HISTORY_DIR = './zabbix'

require_relative 'env'

class Zabbix < Batch::Base
  def query(key)
    ret = nil
    begin
      TCPSocket.open(AGENT_HOST, AGENT_PORT) do | agent |
      send = ['ZBXD', 1, key.length].pack('a4CQ') + key
        agent.write(send)
        got = agent.read
        if ( got )
          a = got[0..13].unpack('a4CQ')
          ret = got[13..-1].unpack("a#{a[2]}")[0]
        end
      end
    rescue
      ;
    end
    ret
  end
  def simple_build(params)
    value = query(params['key'])
    if ( params['class'] )
      params['class'].new({
                            'at' => Time.now,
                            'value' => value,
                            'unit' => params['unit']
                          },
                          'sensor_name' => params['name'])
    else
      print value, "\n"
      nil
    end
  end
  def ratio_build(params)
    value1 = query("#{params['key']}[#{params['target']}]")
    value2 = query("#{params['key']}[#{params['target']},#{params['request']}]")
    value = ( value2.to_f / value1.to_f )
    if ( params['class'] )
      params['class'].new({
                            'at' => Time.now,
                            'value' => value,
                            'unit' => ""
                          },
                          'sensor_name' => params['name']).
        to_requested!(params['unit'])
    else
      print value, "\n"
      nil
    end
  end
  def diff_build(params)
    begin
      str = IO.read("#{HISTORY_DIR}/#{params['name']}")
      a = str.split(':')
      at1 = Time.at(a[0].to_i)
      value1 = a[1].to_i
    rescue
      at1 = nil
    end
    value2 = query(params['key'])
    at2 = Time.now
    if ( !File.exist?(HISTORY_DIR) )
      Dir.mkdir(HISTORY_DIR, 0775)
    end
    IO.write("#{HISTORY_DIR}/#{params['name']}", "#{at2.to_i}:#{value2}\n")
    if ( at1 )
      value = ( value2.to_i - value1 ) / ( at2.to_i - at1.to_i )
      if ( params['class'] )
        params['class'].new({
                              'at' => at2,
                              'value' => value,
                              'unit' => params['unit']
                            },
                            'sensor_name' => params['name'])
      else
        print value, "\n"
        nil
      end
    else
      nil
    end
  end
  def run
    rec = Array.new
    ITEMS.each do | param |
      case param['type']
      when :simple
        data = simple_build(param)
      when :ratio
        data = ratio_build(param)
      when :diff
        data = diff_build(param)
      end
      if ( data )
        rec << data.to_hash
      end
    end
    server = Folloger::HTTPClient.new(SERVER, PORT)
    print "----------------------\n"
    print rec.to_json, "\n"
    print server.put_data(UUID, rec)
    print "----------------------\n"
  end
end

Zabbix.run
