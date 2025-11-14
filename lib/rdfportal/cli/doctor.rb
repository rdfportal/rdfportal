# frozen_string_literal: true

module RDFPortal
  module CLI
    class Doctor < Thor::Group
      include Thor::Actions

      class << self
        def exit_on_failure?
          false
        end
      end

      namespace :doctor

      desc 'Check the system and configuration for RDFPortal'

      # def check_raptor
      #   say "Checking raptor..."
      #
      #   version = obtain('rapper --version')&.strip
      #   result(version.present?, "raptor installation#{version ? " (#{version})" : ''}")
      #
      #   unless version.present?
      #     prescriptions.push <<~MSG
      #       Please install Raptor RDF Syntax Library (https://librdf.org/raptor/).
      #     MSG
      #   end
      # end

      def check_redis
        say "\nChecking redis... (#{RDFPortal.redis})"

        if RDFPortal.redis == :docker
          check_docker

          image = DockerHelper.image_for('redis')
          result(image.present?, "docker image#{' not' unless image} found#{" (#{image})" if image}")

          unless image.present?
            prescriptions.push <<~MSG
              Run the following command to get the image:
              $ docker pull redis
            MSG
            return
          end

          status = DockerHelper.container_status('rdfportal-redis')
          result(status == :running, "docker container is #{status.to_s.tr('_', ' ')} (rdfportal-redis)")

          if status == :not_found
            prescriptions.push <<~MSG
              Run the following command to start the container:
              $ docker run --detach --restart unless-stopped --publish #{RDFPortal.redis_port}:6379 --name rdfportal-redis #{image}
            MSG
            return
          elsif status != :running
            prescriptions.push <<~MSG
              Run the following command to start the container:
              $ docker start rdfportal-redis
            MSG
            return
          end

          pong = check_status('docker exec rdfportal-redis redis-cli ping >/dev/null 2>&1')
          result(pong.present?, "redis is #{'not ' unless pong}running with docker")
        else
          version = capture_output('redis-server --version')&.strip
          result(version.present?, "redis installation#{" (#{version})" if version}")

          if version
            pong = check_status("redis-cli ping -h #{RDFPortal.redis_host} -p #{RDFPortal.redis_port} >/dev/null 2>&1")
            result(pong.present?, "redis is running at #{RDFPortal.redis_host}:#{RDFPortal.redis_port}")
          end
        end
      end

      def check_faktory
        say "\nChecking faktory... (#{RDFPortal.faktory})"

        if RDFPortal.faktory == :docker
          check_docker

          image = DockerHelper.image_for(RDFPortal::Job::DOCKER_IMAGE)
          result(image.present?, "docker image#{' not' unless image} found#{" (#{image})" if image}")

          unless image.present?
            prescriptions.push <<~MSG
              Run the following command to get the image:
              $ docker pull #{RDFPortal::Job::DOCKER_IMAGE}
            MSG
            nil
          end
        else
          version = if (lines = capture_output("#{RDFPortal::Job.faktory_bin} -v")&.lines).present?
                      lines&.first&.strip
                    end

          result(version.present?, "faktory installation#{" (#{version})" if version}")
        end
      end

      def check_virtuoso
        say "\nChecking virtuoso... (#{RDFPortal.virtuoso})"

        if RDFPortal.faktory == :docker
          check_docker

          # TODO: extract constant
          repo = 'openlink/virtuoso-opensource-7:7.2.15'
          image = DockerHelper.image_for(repo)
          result(image.present?, "docker image#{' not' unless image} found#{" (#{image})" if image}")

          unless image.present?
            prescriptions.push <<~MSG
              Run the following command to get the image:
              $ docker pull #{repo}
            MSG
            nil
          end
        else
          virtuoso = capture_output('virtuoso-t --help 2>&1')&.split("\n")&.find { |x| x.start_with?('Version') }
          result(virtuoso.present?, "virtuoso installation#{" (#{virtuoso})" if virtuoso}")
        end
      end

      def print_prescription
        return if prescriptions.blank?

        say
        say '-' * 20

        prescriptions.uniq.each do |str|
          say str
          say
        end
      end

      SUCCESS = "\u2713"
      FAILURE = "\u2717"

      require 'rdfportal/cli/helper'

      include CLI::Helper

      private

      def prescriptions
        @prescriptions ||= []
      end

      def result(success, message, **options)
        icon = success ? shell.set_color(SUCCESS, :green) : shell.set_color(FAILURE, :red)
        message = "#{shell.set_color("[#{icon}]", :bold)} #{message}"

        message.prepend(options[:prepend]) if options[:prepend]

        say message
      end

      def check_docker
        result(installed = DockerHelper.docker_installed?, 'docker installation')

        unless installed
          prescriptions.push 'If you want to prepare redis with docker, please install docker engine first.'
          return
        end

        result(running = DockerHelper.docker_running?, "docker daemon is#{' not' unless running} running")

        return if running

        prescriptions.push 'Start docker daemon or check if you have permission to run docker commands.'
      end
    end
  end
end
