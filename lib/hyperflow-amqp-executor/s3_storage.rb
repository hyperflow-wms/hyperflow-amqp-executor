require 'fog'

module Executor
  module S3Storage
    def storage_init
      @s3 = Fog::Storage.new({
        provider:                 'AWS',
        aws_access_key_id:        ENV['AWS_ACCESS_KEY_ID'],
        aws_secret_access_key:    ENV['AWS_SECRET_ACCESS_KEY']
      })  
    end
  
    def stage_in
      @bucket = @s3.directories.get(@job.options.bucket)

      @job.inputs.each do |file|
        Executor::logger.info "[#{@id}] Downloading #{file.name}"
        File.open(@workdir+"/"+file.name, File::RDWR|File::CREAT) do |local_file|
          @bucket.files.get(@job.options.prefix+file.name) do |chunk, remaining_bytes, total_bytes|
            local_file.write(chunk)
            # print "\rDownloading #{file.name}: #{100*(total_bytes-remaining_bytes)/total_bytes}%"
          end
        end
      end
    end
  
    def stage_out
      @job.outputs.each do |file|
        Executor::logger.info "[#{@id}] Uploading #{file.name}"
        @bucket.files.create(key: @job.options.prefix+file.name, body: File.open(@workdir+"/"+file.name))
      end
    end
  
    def workdir(&block)
      Dir::mktmpdir(&block)
    end
  end
end