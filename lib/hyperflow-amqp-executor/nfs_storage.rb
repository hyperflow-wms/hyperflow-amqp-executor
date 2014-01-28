require 'fog'

module Executor
  module NFSStorage
    def stage_in
      @job.inputs.each do |file|
        Executor::logger.debug "[#{@id}] Copying #{file.name} to tmpdir"
        FileUtils.copy(@job.options.workdir + file.name, @workdir + "/" + file.name)
      end
    end

    def stage_out
      @job.outputs.each do |file|
        Executor::logger.debug "[#{@id}] Copying #{file.name} from tmpdir"
        FileUtils.copy(@workdir + "/" + file.name, @job.options.workdir + file.name)
      end
    end

    def workdir(&block)
      Dir::mktmpdir(&block)
    end
  end
end