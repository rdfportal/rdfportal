# frozen_string_literal: true

module RDFPortal
  module Repository
    class Dataset < Pathname
      include Configurable

      class << self
        METADATA_PROC = lambda do |file|
          {
            mtime: file.mtime,
            md5sum: Digest::MD5.file(file).hexdigest
          }
        end

        def metadata(path)
          path.find
              .filter(&:file?)
              .to_h { |x| [x.relative_path_from(path).to_s, METADATA_PROC.call(x)] }
        end

        def metadata_identical?(lhs, rhs)
          lhs.deep_symbolize_keys == rhs.deep_symbolize_keys
        end

        def link_tree(src, dest)
          src = src.expand_path
          dest = dest.expand_path
          raise Error, "No such file or directory: #{src}" unless src.exist?

          if src.file?
            path = if dest.exist? && dest.directory?
                     dest.join(src.basename)
                   else
                     dest.dirname.mkpath unless dest.dirname.exist?
                     dest
                   end

            if path.exist?
              RDFPortal.logger.debug(self) { "#{path} -> #{src} (skipped)" }
              return
            end

            RDFPortal.logger.debug(self) { "#{path} -> #{src}" }
            path.make_link(src)
          else
            src.find.filter(&:file?).each do |x|
              path = dest.join(x.relative_path_from(src))
              path.dirname.mkpath unless path.dirname.exist?

              if path.exist?
                RDFPortal.logger.debug(self) { "#{path} -> #{src} (skipped)" }
                next
              end

              RDFPortal.logger.debug(self) { "#{path} -> #{x}" }
              path.make_link(x)
            end

            src.find.filter(&:directory?).reverse_each do |x|
              if x.children.empty?
                x.rmdir
              else
                dest.join(x.relative_path_from(src)).utime(x.atime, x.mtime)
              end
            end
          end
        end
      end

      CACHE_FILE_NAME = '.cache.yml'
      LATEST_DIR_NAME = 'latest'
      VERSION_FORMAT = '%Y%m%d'
      VERSION_REGEX = /\A(?<year>[1-9]\d{3})(?<month>0[1-9]|1[0-2])(?<day>0[1-9]|[12][0-9]|3[01])\Z/

      def new_dir
        @new_dir ||= join(new_dir_name)
      end

      def latest
        join(LATEST_DIR_NAME)
      end

      def cache
        join(CACHE_FILE_NAME)
      end

      def update_index(metadata = {}, **options)
        hash = {
          latest: latest.realpath.basename.to_s,
          updated_at: options[:updated_at].is_a?(Time) ? options[:updated_at] : Time.now,
          metadata: metadata
        }

        save_yaml(cache.to_s, hash)
      end

      def index
        return {} unless cache.exist?

        load_yaml(cache)
      end

      def mark_latest(to)
        latest.unlink if latest.exist?
        latest.make_symlink(to)
      end

      def prune(preserve)
        return unless preserve.positive?

        versions.reverse.drop(preserve).each do |x|
          RDFPortal.logger.info(self.class) { "Remove old version: #{x.expand_path}" }
          FileUtils.rm_r(x.expand_path)
        end
      end

      def versions
        children.filter { |x| x.directory? && !x.symlink? && VERSION_REGEX.match?(x.basename.to_s) }
                .sort_by { |x| [(m = VERSION_REGEX.match(x.basename.to_s))[:year].to_i, m[:month].to_i, m[:day].to_i] }
      end

      private

      def new_dir_name
        @new_dir_name ||= Time.now.strftime(VERSION_FORMAT)
      end
    end
  end
end
