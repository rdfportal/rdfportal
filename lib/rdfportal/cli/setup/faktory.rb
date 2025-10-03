# frozen_string_literal: true

module RDFPortal
  module CLI
    module Setup
      class Faktory < Thor::Group
        include Thor::Actions

        class << self
          def exit_on_failure?
            false
          end
        end

        desc 'Install Faktory'

        def install_go
          return if go_bin && File.executable?(go_bin)

          inside File.join(RDFPortal.home, 'opt') do
            latest = capture_output('curl -s https://go.dev/VERSION?m=text | head -n1')&.strip
            abort('Failed to get latest go version') unless latest

            os = capture_output("uname -s | tr '[:upper:]' '[:lower:]'")&.strip || abort('Failed to get OS name')
            arch = case capture_output('uname -m')&.strip
                   when 'x86_64', 'amd64'
                     'amd64'
                   when 'aarch64', 'arm64'
                     'arm64'
                   else
                     abort "Unknown architecture: #{arch}"
                   end

            filename = "#{latest}.#{os}-#{arch}.tar.gz"

            unless File.exist?(filename)
              say 'Downloading latest go binary'
              run "wget https://go.dev/dl/#{filename}", verbose: false
            end

            run 'rm -rf go', verbose: false
            run "tar -xzf #{filename}", verbose: false
            run "rm #{filename}", verbose: false

            version = capture_output("#{go_bin} version")&.strip

            say "Installed #{version}"
          end
        end

        def install_factory
          inside File.join(RDFPortal.home, 'opt') do
            run 'git clone https://github.com/contribsys/faktory.git' unless Dir.exist?('faktory')

            inside 'faktory' do
              run 'git pull'
              FileUtils.rm_rf('bin')
              run "#{go_bin} build -o bin/faktory ./cmd/faktory"
            end
          end
        end

        private

        require 'rdfportal/cli/helper'

        include CLI::Helper

        def go_bin
          bin = File.join(RDFPortal.home, 'opt', 'go', 'bin', 'go')

          if File.exist?(bin) && File.executable?(bin)
            bin
          else
            capture_output('which go', capture: true, abort_on_failure: false)&.strip
          end
        end
      end
    end
  end
end
