# frozen_string_literal: true

module RDFPortal
  module Interaction
    module Dataset
      class Update < Base
        string :group, default: nil

        integer :preserve, default: nil

        attr_reader :directory

        include ExternalCommand

        def initialize(inputs = {})
          raise(Error, 'directory is required') unless (dir = inputs.delete(:directory))

          @directory = Pathname.new(dir)
          @metadata = inputs.delete(:metadata)

          super
        end

        # @return [RDFPortal::Result]
        def execute
          @metadata ||= Repository::Dataset.metadata(target_dir)

          repository.mark_latest(target_dir.basename)
          repository.update_index(@metadata)

          repository.prune(preserve) if preserve&.positive?

          Result.new(:success, "Updated to #{target_dir.basename}")
        rescue StandardError => e
          RDFPortal.logger.error(self.class) { e.full_message }
          Result.new(:error, 'Update error', e.message)
        end

        private

        def group_name
          group ? "#{directory.basename}/#{group}" : directory.basename
        end

        def repository
          @repository ||= if group
                            Repository::Dataset.new(directory.join(group))
                          else
                            Repository::Dataset.new(directory)
                          end
        end

        def target_dir
          @target_dir ||= begin
                            versions = repository.versions

                            if repository.latest.exist?
                              latest = repository.latest.realpath.basename.to_s
                              if latest.match?(Repository::Dataset::VERSION_REGEX)
                                versions.delete_if { |x| x.basename.to_s <= latest }
                              end
                            end

                            versions.last || raise(Error, 'Updatable dataset not found.')
                          end
        end
      end
    end
  end
end
