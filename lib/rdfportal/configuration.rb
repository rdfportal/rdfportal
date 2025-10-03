# frozen_string_literal: true

require 'dotenv'

module RDFPortal
  module Configuration
    CONFIG = File.join(Dir.home, '.rdfportal', 'config')

    DEFAULTS = {
      RDFPORTAL_CONFIG_DIR: File.join(Dir.home, 'rdfportal', 'config'),
      RDFPORTAL_DATASETS_DIR: File.join(Dir.home, 'rdfportal', 'datasets'),
      RDFPORTAL_FAKTORY: 'system',
      RDFPORTAL_FAKTORY_HOST: 'localhost',
      RDFPORTAL_FAKTORY_NETWORK_PORT: '7419',
      RDFPORTAL_FAKTORY_WEBUI_PORT: '7420',
      RDFPORTAL_FAKTORY_PASSWORD: nil,
      RDFPORTAL_REDIS: 'system',
      RDFPORTAL_REDIS_HOST: 'localhost',
      RDFPORTAL_REDIS_PORT: '6379',
      RDFPORTAL_SLACK_WEBHOOK_URL: nil,
      RDFPORTAL_VIRTUOSO: 'system',
      RDFPORTAL_VIRTUOSO_PASSWORD: 'dba',
      RDFPORTAL_WORKER_FETCH_CONCURRENCY: 5,
      RDFPORTAL_WORKER_LOAD_CONCURRENCY: 1,
      RDFPORTAL_WORKER_STAT_CONCURRENCY: 1
    }.freeze

    unless File.exist?(CONFIG)
      FileUtils.mkdir_p(File.dirname(CONFIG))
      File.write(CONFIG, "# created by rdfportal at #{Time.now}\n\n")
    end

    File.read(CONFIG).lines.then do |lines|
      DEFAULTS.each do |key, value|
        File.write(CONFIG, "#{key}=#{value}\n", mode: 'a') if lines.grep(/^#{key}=/).empty?
      end
    end

    Dotenv.load(CONFIG)

    def debug?
      ENV.fetch('DEBUG', nil)
    end

    def config_dir
      Pathname.new(ENV.fetch('RDFPORTAL_CONFIG_DIR'))
    end

    # Default directory if dataset.yaml is missing
    def datasets_dir
      Pathname.new(ENV.fetch('RDFPORTAL_DATASETS_DIR'))
    end

    def slack_webhook_url
      ENV.fetch('RDFPORTAL_SLACK_WEBHOOK_URL', nil)
    end

    def redis
      %i[system docker].find { |x| x.to_s == ENV.fetch('RDFPORTAL_REDIS', 'system') }
    end

    def redis_host
      ENV.fetch('RDFPORTAL_REDIS_HOST', 'localhost')
    end

    def redis_port
      ENV.fetch('RDFPORTAL_REDIS_PORT', 6379).to_i
    end

    def faktory
      %i[system docker].find { |x| x.to_s == ENV.fetch('RDFPORTAL_FAKTORY', 'system') }
    end

    def faktory_host
      ENV.fetch('RDFPORTAL_FAKTORY_HOST', 'localhost')
    end

    def faktory_network_port
      ENV.fetch('RDFPORTAL_FAKTORY_NETWORK_PORT', 7419).to_i
    end

    def faktory_webui_port
      ENV.fetch('RDFPORTAL_FAKTORY_WEBUI_PORT', 7420).to_i
    end

    def faktory_password
      ENV.fetch('RDFPORTAL_FAKTORY_PASSWORD', nil)
    end

    def virtuoso
      %i[system docker].find { |x| x.to_s == ENV.fetch('RDFPORTAL_VIRTUOSO', 'system') }
    end

    def virtuoso_password
      ENV.fetch('RDFPORTAL_VIRTUOSO_PASSWORD', 'dba')
    end

    def worker_fetch_concurrency
      ENV.fetch('RDFPORTAL_WORKER_FETCH_CONCURRENCY', 5).to_i
    end

    def worker_load_concurrency
      ENV.fetch('RDFPORTAL_WORKER_LOAD_CONCURRENCY', 1).to_i
    end

    def worker_stat_concurrency
      ENV.fetch('RDFPORTAL_WORKER_STAT_CONCURRENCY', 1).to_i
    end
  end
end
