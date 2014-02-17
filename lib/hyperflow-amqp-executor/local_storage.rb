module Executor
  module LocalStorage
    def workdir
      yield @job.options.workdir
    end
  end
end

