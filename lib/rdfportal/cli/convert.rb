# frozen_string_literal: true

module RDFPortal
  module CLI
    class Convert < Thor
      include ExternalCommand

      class << self
        def exit_on_failure?
          true
        end
      end

      LINES_PER_FILE = 10_000_000

      desc 'ntriples <FILE>', 'Convert a RDF to N-Triples'
      option :force, aliases: '-f', type: :string, desc: 'Overwrite output files'
      option :output, aliases: '-o', type: :string, desc: 'Output directory'
      option :split, type: :boolean, default: true, desc: 'Split output files'

      def ntriples(file)
        extname = File.extname(file)
        extname = File.extname(File.basename(file, extname)) + extname if %w[.gz .bz2 .xz].include?(extname)

        pattern = File.expand_path("#{File.basename(file, extname)}*.nt.gz", options[:output])
        re = /#{Regexp.escape(File.basename(file, extname))}(.\d+)?.nt.gz/

        if !options[:force] && Dir.glob(pattern).any? { |x| File.basename(x).match?(re) }
          yes?('Overwrite existing files? [y/N]:') || abort('Aborted')
        end

        Dir.mktmpdir do |dir|
          jar = RDFPortal.vendor_lib_dir.join('ConvRDF', 'ConvRDF.jar').to_s
          path = File.expand_path(File.basename(file, extname), dir)
          cmd = [
            'java',
            '-jar',
            %("#{jar}"),
            %("#{file}")
          ]

          if options[:split]
            cmd.push('|',
                     find_bin('split'),
                     "--lines=#{LINES_PER_FILE}",
                     '--suffix-length=10',
                     '--numeric-suffixes=0',
                     '--additional-suffix=.nt.gz',
                     %(--filter='gzip > "#{path}$FILE"'),
                     '-',
                     '.')
          else
            cmd.push('|', 'gzip', '>', %("#{path}.nt.gz"))
          end

          run_cmd!(cmd.join(' '))

          FileUtils.mkdir_p(options[:output]) if options[:output]

          if options[:split]
            re = /\.(\d+)\.nt\.gz$/
            n = 0
            dst = nil

            Dir.each_child(dir) do |child|
              n = child[re, 1].to_i
              src = File.expand_path(child, dir)
              dst = File.expand_path(child.sub(re, ".#{n}.nt.gz"), options[:output])

              FileUtils.mv(src, dst)
            end

            FileUtils.mv(dst, dst.sub(re, '.nt.gz')) if n.zero? && dst
          else
            FileUtils.mv("#{path}.nt.gz", options[:output])
          end
        end
      rescue Error => e
        abort e.message
      rescue StandardError => e
        abort e.full_message
      end
    end
  end
end
