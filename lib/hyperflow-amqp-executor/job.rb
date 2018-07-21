
require_relative 'database_loger'

module Executor
  class Job
    attr_reader :metrics
    
    def initialize(id, job)
      @job = job
      @id = id

      @dataLoger = DatabaseLoger.new(ENV['INFLUXDB_URL'],Executor::id,@id,@job.options.procId,@job.options.hfId, @job.options.wfid,@job.executable)

      @metrics = {
              timestamps: { },
              executor: Executor::id
            }
        
      storage_module = case (@job.options.storage or Executor::settings.storage)
      when 's3', 'cloud'
        CloudStorage
      when 'local'
        LocalStorage
      when 'nfs'
        NFSStorage
      when 'plgdata'
        PLGDataStorage
      when 'gridftp'
        GridFTPStorage
      else
        raise "Unknown storage #{@job.storage}"
      end
      self.extend(storage_module)
    end

    def run
      @metrics[:timestamps]["job.started"] = Executor::publish_event 'job.started', "job.#{@id}.started", job: @id, thread: Thread.current.__id__
      @metrics[:thread] = Thread.current.__id__

      @dataLoger.log_start_job()

      results = {}
      
      workdir do |tmpdir|
        @workdir = tmpdir
        raise "Couldn't get workdir" unless @workdir

        storage_init if self.respond_to? :storage_init

        if self.respond_to? :stage_in
          publish_events "stage_in" do
            _ , @metrics[:stage_in]     = time { stage_in }
            @metrics[:input_size]       = input_size
            {bytes: @metrics[:input_size], time: @metrics[:stage_in]}
          end
        else
          @metrics[:input_size] = input_size
        end

        publish_events "execution" do
          results, @metrics[:execution] = time { execute }
          { executable: @job.executable, exit_status: results[:exit_status], time: @metrics[:execution] }
        end

        if self.respond_to? :stage_out
          publish_events "stage_out" do
            _, @metrics[:stage_out]     = time { stage_out }
            @metrics[:output_size]      = output_size
            { bytes: @metrics[:output_size], time: @metrics[:stage_out] }
          end
        else
          @metrics[:output_size] = output_size
        end

      end
      @metrics[:timestamps]["job.finished"] = Executor::publish_event 'job.finished', "job.#{@id}.finished", job: @id, executable: @job.executable, exit_status: results[:exit_status], metrics: @metrics, thread: Thread.current.__id__

      results[:metrics] = @metrics
      results
    end

    def publish_events(name)
      @metrics[:timestamps]["#{name}.started"]  = Executor::publish_event "job.#{name}.started", "job.#{@id}.#{name}.started", job: @id, thread: Thread.current.__id__
      @dataLoger.log_start_subStage(name)
      results = yield
      @metrics[:timestamps]["#{name}.finished"] = Executor::publish_event "job.#{name}.finished", "job.#{@id}.#{name}.finished", {job: @id, thread: Thread.current.__id__}.merge(results || {})
      if(name == "stage_out")
        @dataLoger.log_finish_job()
      end
      results
    end

    def docker_cmd
      if defined?(@job.options.container) && @job.options.container != ""
        case (@job.options.storage or Executor::settings.storage)
        when 's3', 'cloud'
          Executor::logger.debug "[#{@id}] defined #{@job.options.container}"
          ["docker",
          "run",
          "-v",
          "/tmp:/tmp",
          "-w="+ @workdir,
          @job.options.container
          ]
        when 'local'
          Executor::logger.debug "[#{@id}] defined #{@job.options.container}"
          ["docker",
          "run",
          "-v",
          "/var/run/docker.sock:/var/run/docker.sock",
          "-v",
          @job.options.workdir+":"+Executor::settings.docker_mount,
          "-w="+Executor::settings.docker_mount,
          @job.options.container
          ]
        end
      else
        []
      end
    end

    def cmdline
      if @job.args.is_a? Array
       ( docker_cmd + [@job.executable] + @job.args).map { |e| e.to_s }
     else
       "#{@job.executable} #{@job.args}"
     end
    end

    def execute
      begin
        Executor::logger.debug "[#{@id}] Executing #{cmdline}"
        stdout, stderr, status = Open3.capture3(*cmdline, chdir: @workdir)
        {exit_status: status, stderr: stderr, stdout: stdout}
      rescue Exception => e
        Executor::logger.error "[#{@id}] Error executing job: #{e}"
        Executor::logger.debug "[#{@id}] Backtrace\n#{e.backtrace.join("\n")}"
        {exit_status: -1, exceptions: [e]}
      end
    end

    def input_size
      @job.inputs.map{ |file| begin File.size(@workdir+"/"+file.name) rescue 0 end }.reduce(:+) or 0
    end

    def output_size
      @job.outputs.map{ |file| begin File.size(@workdir+"/"+file.name) rescue 0 end }.reduce(:+) or 0
    end
  end
end