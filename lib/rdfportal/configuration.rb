# frozen_string_literal: true

require 'dotenv'

module RDFPortal
  module Configuration
    REQUIRED_ENV_VARS = %w[RDFPORTAL_CONFIG_DIR RDFPORTAL_DATASETS_DIR].freeze

    DEFAULTS = {
      RDFPORTAL_CONFIG_DIR: File.join(Dir.home, 'rdfportal', 'config'),
      RDFPORTAL_DATASETS_DIR: File.join(Dir.home, 'rdfportal', 'datasets')
    }.freeze

    CONFIG_FILE = RDFPortal.home.join('config').to_s

    unless File.exist?(CONFIG_FILE)
      FileUtils.mkdir_p(File.dirname(CONFIG_FILE))
      File.write(CONFIG_FILE, "# created by rdfportal at #{Time.now}\n\n")
    end

    File.read(CONFIG_FILE).lines.then do |lines|
      REQUIRED_ENV_VARS.each do |key|
        next if lines.grep(/^#{key}=/).any?

        File.write(CONFIG_FILE, "#{key}=#{DEFAULTS[key]}\n", mode: 'a')
      end
    end

    Dotenv.load(CONFIG_FILE)

    def debug?
      ENV.fetch('DEBUG', nil)
    end

    def config_dir
      ENV.fetch('RDFPORTAL_CONFIG_DIR').then { |x| Pathname.new(x) }
    end

    # Default directory if dataset.yaml is missing
    def datasets_dir
      ENV.fetch('RDFPORTAL_DATASETS_DIR').then { |x| Pathname.new(x) }
    end

    def slack_webhook_url
      ENV.fetch('RDFPORTAL_SLACK_WEBHOOK_URL', nil)
    end

    def redis
      ENV.fetch('RDFPORTAL_REDIS', 'system').then(&:to_sym).tap do |x|
        raise Error, "Invalid value for RDFPORTAL_REDIS: #{x}" unless %i[system docker].include?(x)
      end
    end

    def redis_host
      ENV.fetch('RDFPORTAL_REDIS_HOST', 'localhost')
    end

    def redis_port
      ENV.fetch('RDFPORTAL_REDIS_PORT', 6379).to_i
    end

    def faktory
      ENV.fetch('RDFPORTAL_FAKTORY', 'system').then(&:to_sym).tap do |x|
        raise Error, "Invalid value for RDFPORTAL_FAKTORY: #{x}" unless %i[system docker].include?(x)
      end
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
      ENV.fetch('RDFPORTAL_VIRTUOSO', 'system').then(&:to_sym).tap do |x|
        raise Error, "Invalid value for RDFPORTAL_VIRTUOSO: #{x}" unless %i[system docker].include?(x)
      end
    end

    def virtuoso_password
      ENV.fetch('RDFPORTAL_VIRTUOSO_PASSWORD', 'dba')
    end

    def virtuoso_home
      ENV.fetch('RDFPORTAL_VIRTUOSO_HOME', nil).then { |x| Pathname.new(x) if x }
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
