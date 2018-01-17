$LOAD_PATH << "./libs"
require 'data_abstraction'
require 'folloger_http_client'

require_relative 'ifttt_http_client'

class Checker
  def initialize(stream_uuid, data_class_name)
    @stream_uuid = stream_uuid
    @data_class_name = data_class_name
  end
  private
  def download
    server = Folloger::HTTPClient.new(SERVER, PORT)
    param = {session_key: USER_SESSION_KEY, count: 1}
    p server.get_data(@stream_uuid, param)
  end
  def upload(data)
    ifttt_server = Ifttt::HTTPClient.new(IFTTT_SERVER, IFTTT_PORT)
    p ifttt_server.put_data(IFTTT_EVENT, IFTTT_KEY, data)
  end
  def update_current_data
    data = download
    if data.length > 0
      name = data[0]["name"]
      param = {'at' => data[0]["at"],
               'value' => data[0]["data"]["value"],
               'unit' => data[0]["data"]["unit"]}
      @current_data =  DataAbstraction::SensorData.const_get(@data_class_name).new(param, 'sensor_name' => name)
      @current_data.to_requested!(DataAbstraction::SensorData.const_get(@data_class_name).standard_unit)
    else
      @current_data =  nil
    end
  end
end
