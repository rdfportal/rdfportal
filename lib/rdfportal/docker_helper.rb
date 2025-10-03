# frozen_string_literal: true

module RDFPortal
  class DockerHelper
    class << self
      def docker_installed?
        cmd.run!('which', 'docker').success?
      end

      def docker_running?
        cmd.run!('docker', 'ps').success?
      end

      def image_for(repository)
        ret = cmd.run!('docker', 'images', '--format', '{{.Repository}}:{{.Tag}}', repository.to_s)

        return nil unless ret.success?

        ret.out.lines.first&.strip
      end

      def pull_image(repository, tag = nil, **options)
        options[:printer] ||= :quiet
        cmd(**options).run('docker', 'pull', "#{repository}#{":#{tag}" if tag}")
      end

      def run_container(repository, tag = nil,
                        name:,
                        detach: false,
                        remove: false,
                        interactive: false,
                        tty: false,
                        env: {},
                        volume: {},
                        publish: {},
                        **options)
        cmd = []
        cmd << 'docker'
        cmd << 'run'
        cmd << '--detach' if detach
        cmd << '--rm' if remove
        cmd << '--interactive' if interactive
        cmd << '--tty' if tty
        env.each do |k, v|
          cmd << '--env'
          cmd << "#{k}=#{v}"
        end
        volume.each do |k, v|
          cmd << '--volume'
          cmd << "#{k}:#{v}"
        end
        publish.each do |k, v|
          cmd << '--publish'
          cmd << "#{k}:#{v}"
        end
        if name
          cmd << '--name'
          cmd << name
        end
        cmd << image_for("#{repository}#{":#{tag}" if tag}")

        options[:printer] ||= :quiet
        cmd(**options).run(*cmd)
      end

      def stop_container(container, **options)
        options[:printer] ||= :quiet
        cmd(**options).run('docker', 'stop', container)
      end

      # @return [Symbol] :created | :running | :exited | :paused | :restarting | :not_found
      def container_status(container, **options)
        options[:printer] ||= :null
        cmd(**options).run('docker', 'inspect', '--format', '{{.State.Status}}', container.to_s)
                      .out
                      .strip
                      .presence
                      .to_sym
      rescue StandardError
        :not_found
      end

      private

      def cmd(**options)
        options[:printer] ||= :null
        TTY::Command.new(**options)
      end
    end
  end
end
