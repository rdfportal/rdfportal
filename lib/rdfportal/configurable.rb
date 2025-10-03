# frozen_string_literal: true

module RDFPortal
  module Configurable
    def load_yaml(file)
      yaml = ERB.new(File.read(file)).result
      doc = YAML.load(yaml, aliases: true, permitted_classes: [Symbol, Time])

      doc.is_a?(Array) ? { data: doc }.deep_symbolize_keys.values[0] : Hash(doc).deep_symbolize_keys
    end

    def save_yaml(file, hash)
      File.write(file, YAML.dump(hash.deep_stringify_keys))
    end
  end
end
