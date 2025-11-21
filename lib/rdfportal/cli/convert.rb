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
      option :split, type: :boolean, default: true, desc: 'Split output files'
      option :output, aliases: '-o', type: :string, desc: 'Output directory'

      def ntriples(file)
        basename = File.basename(file)
        extname = File.extname(basename)
        extname = File.extname(File.basename(basename, extname)) + extname if %w[.gz .bz2 .xz].include?(extname)
        output_template = File.join(*[options[:output], "#{File.basename(basename, extname)}.%d.nt.gz"].compact)

        FileUtils.mkdir_p(options[:output]) if options[:output]

        reader, writer = IO.pipe

        thread = Thread.new do
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

        path = format(output_template, file_index)
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
          line_count = 0

          path = format(output_template, file_index += 1)
          gz = Zlib::GzipWriter.new(File.open(path, 'w'), Zlib::BEST_COMPRESSION, Zlib::DEFAULT_STRATEGY)
        end

        gz.write(buffer) unless buffer.empty?
        gz.close

        FileUtils.mv(path, path.sub('.0.nt.gz', '.nt.gz')) unless split

        thread.join
      rescue Error => e
        abort e.message
      rescue StandardError => e
        abort e.full_message
      end
    end
  end
end
