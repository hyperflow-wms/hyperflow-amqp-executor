
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

      init_replacements
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

        File.write("#{@workdir}/signals.json", {inputs: @job.inputs.map(&:to_h), outputs: @job.outputs.map(&:to_h)}.to_json)

        if self.respond_to? :stage_in
          publish_events "stage_in" do
            _ , @metrics[:stage_in]     = time do
              @job.inputs.each do |input|
                input.files.split(":").each stage_in unless input.files.nil?
              end
            end
            @metrics[:input_size]       = input_size
            {bytes: @metrics[:input_size], time: @metrics[:stage_in]}
          end
        else
          @dataLoger.log_start_subStage("stage_in")
          @metrics[:input_size] = input_size
        end

        publish_events "execution" do
          results, @metrics[:execution] = time { execute }
          { executable: @job.executable, exit_status: results[:exit_status], time: @metrics[:execution] }
        end

        if self.respond_to? :stage_out
          publish_events "stage_out" do
            _, @metrics[:stage_out]     = time do
              @job.outputs.each do |output|
                output.files.split(":").each stage_out unless output.files.nil?
              end
            end
            @metrics[:output_size]      = output_size
            { bytes: @metrics[:output_size], time: @metrics[:stage_out] }
          end
        else
          @dataLoger.log_start_subStage("stage_out")
          @dataLoger.log_finish_job()
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

    def init_replacements
      replacements_map = ((@job.inputs + @job.outputs).map do |signal|
        name = signal.name
        signal.to_h.map do |k, v|
          val = if v.is_a? Array then v.join(",") else v end
          ["$#{name}_#{k}", val]
        end
      end).flatten(1)

      @replacements = Hash[replacements_map]
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
          if ENV['NFS_MOUNT'].nil?
            Executor::logger.debug "[#{@id}] defined #{@job.options.container}"
            ["docker",
            "run",
            "-v",
            "/var/run/docker.sock:/var/run/docker.sock",
            "-v",
            @workdir+":"+Executor::settings.docker_mount,
            "-w="+Executor::settings.docker_mount,
            @job.options.container
            ]
          else
            ["docker",
            "run",
            "--privileged=true",
            "-e",
            "NFS_MOUNT="+ENV['NFS_MOUNT'],
            "-w="+@workdir,
            @job.options.container
            ]
          end
        else
          []
        end
      else
        []
      end
    end

    def env
      Hash[@job.env.to_h.map{|k,str| [k, str.gsub(/\$[A-Za-z0-9_]+/, @replacements) ] }]
    end

    def cmdline
     line = if @job.args.is_a? Array
       ( docker_cmd + [@job.executable] + @job.args).map { |e| e.to_s }
     else
       "#{@job.executable} #{@job.args}"
     end
     line.map { |e| e.gsub(/\$[A-Za-z0-9_]+/, @replacements) }
    end

    def execute
      begin
        Executor::logger.debug "[#{@id}] Executing #{cmdline} with env #{env}"
        if docker_cmd.empty?
          stdout, stderr, status = Open3.capture3(env, *cmdline, chdir: @workdir)
        else
          stdout, stderr, status = Open3.capture3(*cmdline)
        end

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
