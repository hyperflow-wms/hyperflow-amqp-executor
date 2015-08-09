require 'fog'

module Executor
  module NFSStorage
    def stage_in(file)
      Executor::logger.debug "[#{@id}] Copying #{file.name} to tmpdir"
      FileUtils.copy(@job.options.workdir + file.name, @workdir + "/" + file.name)
    end

    def stage_out(file)
      Executor::logger.debug "[#{@id}] Copying #{file.name} from tmpdir"
      FileUtils.copy(@workdir + "/" + file.name, @job.options.workdir + file.name)
    end

    def workdir(&block)
      Dir::mktmpdir(&block)
    end
  end
end