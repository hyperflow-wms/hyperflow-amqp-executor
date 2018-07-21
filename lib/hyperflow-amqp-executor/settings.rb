require 'deep_merge'
require 'erb'

module Executor
  class Settings
    class << self
      def load(file=nil)
        settings = defaults
        unless file.nil?
          file_settings = YAML.load(ERB.new(File.read(file)).result)
          settings.deep_merge! file_settings
        end
        RecursiveOpenStruct.new(settings)
      end
    
      def defaults
        {
          amqp_url: ENV['AMQP_URL'],
          storage: 'cloud',
          docker_mount: '/input',
          threads: Executor::cpu_count,
          cloud_storage: {
            provider: "AWS",
            aws_access_key_id:      ENV['AWS_ACCESS_KEY_ID'],
            aws_secret_access_key:  ENV['AWS_SECRET_ACCESS_KEY']
          },
          plgdata: {
            proxy: ENV['X509_USER_PROXY']
          },
          gridftp: {
            proxy: ENV['X509_USER_PROXY']
          }
        }
      end
    end
  end
end