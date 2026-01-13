# frozen_string_literal: true

module RDFPortal
  module CLI
    class Convert < Thor
      class << self
        def exit_on_failure?
          true
        end
      end

      LINES_PER_FILE = 10_000_000
      BUFFER_FLUSH_BYTES = 1024 * 1024

      desc 'ntriples <FILE>', 'Convert a RDF to N-Triples'
      option :force, aliases: '-f', type: :string, desc: 'Overwrite output files'
      option :output, aliases: '-o', type: :string, desc: 'Output directory'
      option :split, type: :boolean, default: true, desc: 'Split output files'

      def ntriples(file)
        extname = File.extname(file)
        extname = File.extname(File.basename(file, extname)) + extname if %w[.gz .bz2 .xz].include?(extname)
        output_template = "#{File.basename(file, extname)}.%d.nt.gz"

        pattern = File.expand_path("#{File.basename(file, extname)}*.nt.gz", options[:output])
        re = /#{Regexp.escape(File.basename(file, extname))}(.\d+)?.nt.gz/

        if !options[:force] && Dir.glob(pattern).any? { |x| File.basename(x).match?(re) }
          yes?('Overwrite existing files? [y/N]:') || abort('Aborted')
        end

        reader, writer = IO.pipe

        Dir.mktmpdir do |dir|
          converter = Thread.new do
            cmd = TTY::Command.new(printer: :null)
            jar = RDFPortal.vendor_lib_dir.join('ConvRDF', 'ConvRDF.jar').to_s
            cmd.run('java', '-jar', jar, file) do |out, _err|
              writer << out if out
            end
          ensure
            writer.close
          end

          split = false
          line_count = 0
          file_index = 0
          buffer = +''

          path = File.expand_path(format(output_template, file_index), dir)
          gz = Zlib::GzipWriter.new(File.open(path, 'w'), Zlib::BEST_COMPRESSION, Zlib::DEFAULT_STRATEGY)

          reader.each_line do |line|
            if (buffer << line).bytesize >= BUFFER_FLUSH_BYTES
              gz.write(buffer)
              buffer.clear
            end

            next unless options[:split]
            next unless (line_count += 1) >= LINES_PER_FILE

            gz.write(buffer) unless buffer.empty?
            gz.close
            buffer.clear

            split = true
            file_index += 1
            line_count = 0

            path = File.expand_path(format(output_template, file_index), dir)
            gz = Zlib::GzipWriter.new(File.open(path, 'w'), Zlib::BEST_COMPRESSION, Zlib::DEFAULT_STRATEGY)
          end

          converter.join

          gz.write(buffer) unless buffer.empty?
          gz.close

          unless split
            FileUtils.mv(path, File.expand_path("#{File.basename(path, '.0.nt.gz')}.nt.gz", File.dirname(path)))
          end

          FileUtils.mkdir_p(options[:output]) if options[:output]

          Dir.each_child(dir) do |child|
            FileUtils.mv(File.expand_path(child, dir), File.expand_path(child, options[:output]))
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
