require 'rubygems'
require 'net/http'
require 'cgi'
require 'json'
require 'mime/types'
require 'digest/sha1'

require_relative 'folloger_client_base'

module Folloger
  class HTTPClient < Base
    def initialize(host = "127.0.0.1", port = 7001)
      set_location(host, port)
      set_timeout(120)
      set_retry(MAX_RETRY)
    end
    def put_data(uuid, data, params = {})
      _post("data/#{uuid}", data, 10, params)
    end
    def auth_user(user, pass)
      _post('auth_user', [ user, pass ])
    end
    def get_data(uuid, opt = {})
      args = opt.dup
      _get("data", uuid, args)
    end
    def last_at(uuid, params = {})
      params[:count] = 1
      begin
        ent = get_data(uuid, params)
        from = Time.safe_parse(ent[0]['data']['at'])
      rescue
        from = nil
      end
      from
    end
    def method_missing(name, *args)
      if ( name =~ /^put_(.*)/ )
        _post($1, args[0])
      else
        _get(name, args[0], args[1])
      end
    end
  private
    def _post(func, data = nil, limit = 10, params = {})
      arg = nil
      if ( params )
        params.each do | key, val |
          if ( !arg )
            arg = "#{CGI.escape(key.to_s)}=#{CGI.escape(val.to_s)}"
          else
            arg << "&#{CGI.escape(key.to_s)}=#{CGI.escape(val.to_s)}"
          end
        end
      end
      #p arg
      if ( arg )
        path = "/#{func}?#{arg}"
      else
        path = "/#{func}"
      end

      boundary = Digest::SHA1.hexdigest(Time.now.to_s)
      raise ArgumentError, 'HTTP redirect too deep' if limit == 0
      multipart = {}
      if ( data.instance_of? Array )
        data.each do | rec |
          if  ( rec['data'] ) &&
              ( name = rec['data']['filename'] )
            rec['data']['filename'] = File.basename(name)
            multipart[File.basename(name)] = name
          end
        end
      end
      if ( multipart.size > 0 )
        body = Array.new
        body << "--#{boundary}\r\n"
        body << "Content-Disposition: form-data; name=\"json\";\r\n"
        body << "Content-Type: application/json\r\n\r\n"
        body << data.to_json
        body << "\r\n"
        multipart.each do | name, filename |
          file_data = nil
          File.open(filename, "r") do | file |
            file_data = file.read
          end

          body << "--#{boundary}\r\n"
          body << "Content-Disposition: form-data; name=\"#{name}\"; filename=\"#{filename}\";\r\n"
          body << "Content-Transfer-Encoding: binary\r\n"
          body << "Content-Type: #{MIME::Types.type_for(filename)}\r\n"
          body << "Content-Length: #{file_data.size}\r\n"
          body << "\r\n"
          body << file_data
          body << "\r\n"
        end
        body << "--#{boundary}--\r\n"
        #p body

        req = Net::HTTP::Post.new(path)
        req.set_content_type("multipart/form-data, boundary=#{boundary}")
        req.body = body.join
      else
        req = Net::HTTP::Post.new(path, {
                                    'Content-Type' => 'application/json'} )
        
        req.body = data.to_json
      end
      retry_count = @max_retry
      res = Net::HTTP.new(@host, @port).start do | http |
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
          JSON.parse(res.body)
        else
          {
            code: -30,
            reason: "no data"
          }
        end
      when Net::HTTPRedirection
        set_location(res['location'])
        _post(func, data, limit - 1, params)
      else
        #p res.body
        {
          code: -30,
          reason: res.body
        }
      end
    end
    def _get(func, file, params = {}, limit = 10)
      #p params
      raise ArgumentError, 'HTTP redirect too deep' if limit == 0
      arg = nil
      if ( params )
        params.each do | key, val |
          if ( !arg )
            arg = "#{CGI.escape(key.to_s)}=#{CGI.escape(val.to_s)}"
          else
            arg << "&#{CGI.escape(key.to_s)}=#{CGI.escape(val.to_s)}"
          end
        end
      end
      #p arg
      if ( arg )
        req = Net::HTTP::Get.new("/#{func}/#{file}?#{arg}")
      else
        req = Net::HTTP::Get.new("/#{func}/#{file}")
      end

      retry_count = @max_retry
      res = Net::HTTP.new(@host, @port).start do | http |
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
          JSON.parse(res.body)
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
