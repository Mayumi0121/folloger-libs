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

PORT = 7001
SERVER = "localhost"
UUID = '901c5abf-c07e-4862-9e38-6374acde76ca'

AGENT_HOST = 'localhost'
AGENT_PORT = 10050

ITEMS = [
         {
           'type' => :simple,
           'key' => 'agent.version'
         }, {
           'type' => :simple,
           'key' => 'net.dns[,google.com]'
         }, {
           'type' => :simple,
           'key' => 'vfs.fs.discovery'
         },{
           'type' => :simple,
           'key' => 'system.uptime',
           'class' => DataAbstraction::SensorData::ComputerDuration,
           'unit' => 'sec',
           'name' => 'uptime'
         },{
           'type' => :simple,
           'key' => 'net.tcp.service[ssh]'
         },{
           'type' => :simple,
           'key' => 'net.if.discovery'
         },{
           'type' => :simple,
           'key' => 'system.cpu.load[all,avg1]',
           'class' => DataAbstraction::SensorData::CPULoad,
           'unit' => '',
           'name' => 'avg1'
         },{
           'type' => :simple,
           'key' => 'system.cpu.load[all,avg5]',
           'class' => DataAbstraction::SensorData::CPULoad,
           'unit' => '',
           'name' => 'avg5'
         },{
           'type' => :simple,
           'key' => 'system.cpu.load[all,avg15]',
           'class' => DataAbstraction::SensorData::CPULoad,
           'unit' => '',
           'name' => 'avg15'
         },{
           'type' => :simple,
           'key' => 'vm.memory.size[total]',
           'class' => DataAbstraction::SensorData::MemorySize,
           'unit' => 'B',
           'name' => 'total_memory'
         },{
           'type' => :simple,
           'key' => 'vm.memory.size[used]',
           'class' => DataAbstraction::SensorData::MemorySize,
           'unit' => 'B',
           'name' => 'used_memory'
         },{
           'type' => :simple,
           'key' => 'vm.memory.size[free]',
           'class' => DataAbstraction::SensorData::MemorySize,
           'unit' => 'B',
           'name' => 'free_memory'
         },{
           'type' => :ratio,
           'key' => 'vfs.fs.size',
           'target' => '/',
           'request' => 'free',
           'class' => DataAbstraction::SensorData::DiskRatio,
           'unit' => '%',
           'name' => "disk_free /"
         },{
           'type' => :ratio,
           'key' => 'vfs.fs.size',
           'target' => '/',
           'request' => 'used',
           'class' => DataAbstraction::SensorData::DiskRatio,
           'unit' => '%',
           'name' => "disk_used /"
         },{
           'type' => :ratio,
           'key' => 'vfs.fs.size',
           'target' => '/home',
           'request' => 'free',
           'class' => DataAbstraction::SensorData::DiskRatio,
           'unit' => '%',
           'name' => "disk_free /home"
         },{
           'type' => :ratio,
           'key' => 'vfs.fs.size',
           'target' => '/home',
           'request' => 'used',
           'class' => DataAbstraction::SensorData::DiskRatio,
           'unit' => '%',
           'name' => "disk_used /home"
         },{
           'type' => :diff,
           'key' => 'net.if.in[eth0]',
           'class' => DataAbstraction::SensorData::DataRate,
           'name' => 'in_eth0'
         },{
           'type' => :diff,
           'key' => 'net.if.out[eth0]',
           'class' => DataAbstraction::SensorData::DataRate,
           'name' => 'out_eth0'
         },{
           'type' => :diff,
           'key' => 'net.if.in[tap0]',
           'class' => DataAbstraction::SensorData::DataRate,
           'name' => 'in_tap0'
         },{
           'type' => :diff,
           'key' => 'net.if.out[tap0]',
           'class' => DataAbstraction::SensorData::DataRate,
           'name' => 'out_tap0'
         }
        ]

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
