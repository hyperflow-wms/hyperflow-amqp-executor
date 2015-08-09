module Executor
  module GridFTPStorage
    def storage_init
      raise Exception, "Unable to locate user proxy certificate" if Executor::settings.plgdata.proxy.nil? or !File.exists?(Executor::settings.plgdata.proxy)
      @proxy_file = Executor::settings.gridftp.proxy
    end

    def stage_in(file)
      local_file_name = @workdir + "/" + file.name
      url = @job.options.prefix + "/" + file.name

      Executor::logger.debug "[#{@id}] Downloading #{url} to #{local_file_name}"
      stdout, stderr, status = Open3.capture3({'X509_USER_PROXY' => @proxy_file}, 'globus-url-copy', url, local_file_name, chdir: @workdir)
      unless status == 0
        raise Exception, "Failed downloading input from GridFTP, status: #{status}\nstdout:\n#{stdout}\n\n stderr:\n#{stderr}"
      end
    end

    def stage_out(file)
      local_file_name = @workdir + "/" + file.name
      url = @job.options.prefix + "/" + file.name

      Executor::logger.debug "[#{@id}] Uploading #{file.name} to #{url}"
      stdout, stderr, status = Open3.capture3({'X509_USER_PROXY' => @proxy_file}, 'globus-url-copy', local_file_name, url, chdir: @workdir)
      unless status == 0
        raise Exception, "Failed uploading input from GridFTP, status: #{status}\nstdout:\n#{stdout}\n\n stderr:\n#{stderr}"
      end
    end

    def workdir(&block)
      Dir::mktmpdir(&block)
    end
  end
end