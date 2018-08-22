require 'fog'

module Executor
  module CloudStorage

    @@lastWorkdir = nil

    def storage_init
      @provider = Fog::Storage.new(@job.options.cloud_storage || Executor::settings.cloud_storage.to_h)
    end

    def stage_in
      @bucket = @provider.directories.get(@job.options.bucket)
      @job.inputs.each do |file|
        Executor::logger.debug "exist #{@workdir+"/"+file.name} #{File.exists?(@workdir+"/"+file.name)}"
        unless File.exists?(@workdir+"/"+file.name)
          Executor::logger.debug "[#{@id}] Downloading #{file.name}"
          #Executor::logger.debug "[#{@workdir}] Workdir #{file.name}"
          File.open(@workdir+"/"+file.name, File::RDWR|File::CREAT) do |local_file|
            @bucket.files.get(@job.options.prefix+file.name) do |chunk, remaining_bytes, total_bytes|
              local_file.write(chunk)
              # print "\rDownloading #{file.name}: #{100*(total_bytes-remaining_bytes)/total_bytes}%"
            end
          end
        end
      end
    end

    def stage_out
      @job.outputs.each do |file|
        Executor::logger.debug "[#{@id}] Uploading #{file.name}"
        @bucket.files.create(key: @job.options.prefix+file.name, body: File.open(@workdir+"/"+file.name))
      end
    end

    def store_last_job_options
      @@lastHfId = @job.options.hfId
      @@lastWfId = @job.options.wfid
      @@lastWorkdir = Dir::mktmpdir
    end

    def workdir(&block)
      #Executor::logger.debug "mktmpdir block#{block}"
      if(!ENV["FEATURE_DOWNLOAD"].nil? && ENV["FEATURE_DOWNLOAD"] == "ENABLED")
        if @@lastWorkdir.nil?  
          Executor::logger.debug "@@lastWorkdir.nil? = true"
          store_last_job_options
        else
          Executor::logger.debug "@@lastWorkdir.nil? = false"
          unless @@lastHfId == @job.options.hfId && @@lastWfId == @job.options.wfid
            FileUtils.remove_entry_secure @@lastWorkdir
            store_last_job_options
          end
        end
        yield(@@lastWorkdir)
      else
        Dir::mktmpdir(&block)
      end
    end
  end
end