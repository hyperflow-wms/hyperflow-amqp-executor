require 'amqp'
require 'json'
require 'recursive-open-struct'
require 'open3'
require 'tmpdir'
require 'logger'

require_relative 'hyperflow-amqp-executor/helpers'
require_relative 'hyperflow-amqp-executor/job'
require_relative 'hyperflow-amqp-executor/local_storage'
require_relative 'hyperflow-amqp-executor/cloud_storage'
require_relative 'hyperflow-amqp-executor/nfs_storage'
require_relative 'hyperflow-amqp-executor/plgdata_storage'
require_relative 'hyperflow-amqp-executor/gridftp_storage'
require_relative 'hyperflow-amqp-executor/settings'

module Executor
  class << self
    attr_accessor :events_exchange, :id, :settings

    def logger
      @logger ||= Logger.new($stdout)
    end

    def cpu_count
      unless ENV['THREADS'].nil?
        ENV['THREADS']
      else
        begin
          `nproc`
        rescue
          1
        end
      end.to_i
    end

    def publish_event(type, routing_key, payload = {})
      data = payload
      data['timestamp'] = Time.now.utc.to_f
      data['type']      = type
      data['executor']  = @id
      EM.next_tick do
        logger.debug "Publishing event #{type}"
        @events_exchange.publish(JSON.dump(data), content_type: 'application/json', routing_key: routing_key)
      end
      data['timestamp']
    end
  end
end