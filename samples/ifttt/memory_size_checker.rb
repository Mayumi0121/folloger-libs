require_relative 'checker'
module Checkers
  class MemorySizeChecker < Checker
    DATA_CLASS_NAME = "MemorySize"
    def initialize(stream_uuid, param={})
      if param
        @alert_value = param[:limit]
        @alert_unit = param[:limit_unit]
      end
      super(stream_uuid, DATA_CLASS_NAME)
    end
    def need_notification?
      value = @current_data.value.to_requested(@alert_unit)
      if value.value < @alert_value
        true
      else
        false
      end
    end
    def send_notification
      update_current_data
      value = @current_data.value.to_requested(@alert_unit)
      if need_notification?
        upload({value1: @current_data.at,
                value2: @current_data.sensor_name,
                value3: "#{value.value} #{value.unit}"})
      end
    end
  end
end
