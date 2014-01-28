module Executor
  class Job
    attr_reader :metrics
    
    def initialize(id, job)
      @job = job
      @id = id
      @metrics = {
              timestamps: { },
              worker: Executor::id
            }

      storage_module = case @job.options.storage
      when 's3', 'cloud'
        CloudStorage
      when 'local'
        LocalStorage
      when 'nfs'
        NFSStorage
      else
        raise "Unknown storage #{@job.storage}"
      end

      self.extend(storage_module)
    end

    def run
      @metrics[:timestamps]["job.started"] = Executor::publish_event 'job.started', "job.#{@id}.started", job: @id, thread: Thread.current.__id__
      @metrics[:thread] = Thread.current.__id__

      results = {}
      
      workdir do |tmpdir|
        @workdir = tmpdir

        storage_init if self.respond_to? :storage_init

        if self.respond_to? :stage_in
          publish_events "stage_in" do
            _ , @metrics[:stage_in]     = time { stage_in }
            @metrics[:input_size]       = input_size
            {bytes: @metrics[:input_size], time: @metrics[:stage_in]}
          end
        end

        publish_events "execution" do
          results, @metrics[:execution] = time { execute }
          { executable: @job.executable, exit_status: results[:exit_status], time: @metrics[:execution] }
        end

        if self.respond_to? :stage_out
          publish_events "stage_out" do
            _, @metrics[:stage_out]     = time { stage_out }
            @metrics[:output_size]      = input_size
            { bytes: @metrics[:output_size], time: @metrics[:stage_out] }
          end
        end

      end
      @metrics[:timestamps]["job.finished"] = Executor::publish_event 'job.finished', "job.#{@id}.finished", job: @id, executable: @job.executable, exit_status: results[:exit_status], metrics: @metrics, thread: Thread.current.__id__

      results[:metrics] = @metrics
      results
    end

    def publish_events(name)
      @metrics[:timestamps]["#{name}.started"]  = Executor::publish_event "job.#{name}.started", "job.#{@id}.#{name}.started", job: @id, thread: Thread.current.__id__
      results = yield
      @metrics[:timestamps]["#{name}.finished"] = Executor::publish_event "job.#{name}.finished", "job.#{@id}.#{name}.finished", {job: @id, thread: Thread.current.__id__}.merge(results || {})
      results
    end

    def execute
      begin
        cmdline = "#{@job.executable} #{@job.args}"
        Executor::logger.debug "[#{@id}] Executing #{cmdline}"
        Open3.popen3(cmdline, chdir: @workdir) do |stdin, stdout, stderr, wait_thr|
          {exit_status: wait_thr.value.exitstatus, stderr: stderr.read, stdout: stdout.read} # Should use IO.select!, will break on large stdout/stderr
        end
      rescue Exception => e
        Executor::logger.error "[#{@id}] Error executing job: #{e}"
        {exit_status: -1, exceptions: [e]}
      end
    end

    def input_size
      @job.inputs.map{ |file| File.size(@workdir+"/"+file.name) }.reduce(:+)
    end

    def output_size
      @job.outputs.map{ |file| File.size(@workdir+"/"+file.name) }.reduce(:+)
    end
  end
end