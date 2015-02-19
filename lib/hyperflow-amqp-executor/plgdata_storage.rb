require 'httpclient'
require 'pry'

module Executor
  module PLGDataStorage
    def storage_init
      @http_client = HTTPClient.new()
      @http_client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE # FIXME: !!!! 
      
    end

    def stage_in
      @job.inputs.each do |file|
          local_file_name = @workdir+"/"+file.name
          Executor::logger.debug "[#{@id}] Downloading #{file.name} to #{local_file_name}"
          url = 'https://data.plgrid.pl/download/'+@job.options.prefix+file.name
          payload = {proxy: Executor::settings.plgdata.proxy}

          File.open(local_file_name, File::RDWR|File::CREAT) do |local_file|
            response = @http_client.get(url, payload) do |chunk|
              local_file.write(chunk)
            end
            raise Exception, "Failed downloading input file" unless response.ok?
          end
      end
    end

    def stage_out
      @job.outputs.each do |file|
        Executor::logger.debug "[#{@id}] Uploading #{file.name}"

        local_file_name = @workdir+"/"+file.name
        url = 'https://data.plgrid.pl/upload/'+@job.options.prefix # TODO: wyciac ewentualna sciezke z file.name

        File.open(local_file_name) do |local_file|
          payload = {proxy: Executor::settings.plgdata.proxy, file: local_file}
          response = @http_client.post(url, payload)

          raise Exception, "Failed uploading output file: #{response.content}" unless response.ok?
        end

      end
    end

    def workdir(&block)
      Dir::mktmpdir(&block)
    end
  end
end