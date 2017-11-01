module Batch
  class Locked < StandardError
  end

  class Base
    def self.run(*arguments)
      synchronized do
        new.run(*arguments)
      end
    rescue Batch::Locked
      puts '** other proccess executing **'
    end

    def self.synchronized
      File.open(lock_file_path, 'w') do |lock_file|
        if lock_file.flock(File::LOCK_EX|File::LOCK_NB)
          yield
        else
          raise Batch::Locked, "#{lock_file.path} is locked."
        end
      end
    end
 
    def self.lock_file_path
      "/tmp/#{self.name}.lock"
    end
  end
end
