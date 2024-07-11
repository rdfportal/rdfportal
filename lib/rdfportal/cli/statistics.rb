# frozen_string_literal: true

module RDFPortal
  module CLI
    class Statistics < Thor
      include Configurable

      option :config, required: true, type: :string, aliases: '-c', desc: 'Path to config yaml'
      desc 'generate <RELEASE>', 'Generate statistics from <RELEASE>'

      def generate(release)
        # TODO
        raise NotImplementedError
      end

      option :config, required: true, type: :string, aliases: '-c', desc: 'Path to config yaml'
      desc 'publish <RELEASE>', 'Publish statistics'

      def publish(release)
        # TODO
        raise NotImplementedError
      end
    end
  end
end
