require 'rubygems'
require 'exifr'

$LOAD_PATH << "./libs"
require 'data_abstraction'
require 'folloger_http_client'
require 'batch'

require_relative 'env'

class PictureSender < Batch::Base
  def send_picture(filename)
    server = Folloger::HTTPClient.new(SERVER, PORT)
    date_time = File.mtime(filename)
    param = Hash.new
    begin
      exif = EXIFR::JPEG.new(filename)
      if ( exif.date_time )
        date_time = exif.date_time
      else
        date_time = File.mtime(filename)
      end
      if ( exif.gps )
        param.merge!({
                       'longitude' => exif.gps.longitude,
                       'latitude' => exif.gps.latitude
                     })
      end
    rescue
    end
    param.merge!({
                   'at' => date_time,
                   'filename' => filename
                 })
    rec = Array.new
    ent = DataAbstraction::SensorData::Camera.new(param,
                                                  'sensor_name' => SENSOR_NAME)
    rec << ent.to_hash
    p ent.to_hash
    p server.put_data(CHANNEL_UUID, rec)

  rescue => e
    p e
  end
  def run(filename)
    p filename
    if filename
      send_picture("#{filename}")
    else
      Dir.glob("#{DIR}/*") do | filename |
        send_picture(filename)
      end
    end
  end
end

PictureSender.run(ARGV[0])
