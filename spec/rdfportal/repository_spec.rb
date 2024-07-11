# frozen_string_literal: true

RSpec.describe RDFPortal::Repository do
  require 'active_support/testing/time_helpers'
  include ActiveSupport::Testing::TimeHelpers

  let(:base) { File.expand_path('../../tmp/rdfportal', __dir__) }
  let(:repository) do
    RDFPortal::Repository.new(datasets: File.join(base, 'datasets'), endpoints: File.join(base, 'endpoints'))
  end

  it 'return datasets path' do
    expect(repository.datasets.to_s).to eq File.join(base, 'datasets')
  end

  it 'return graph.tsv path of a dataset' do
    expect(repository.datasets['dataset'].graph_file.to_s).to eq File.join(base, 'datasets', 'dataset', 'graph.tsv')
  end

  it 'return endpoints path' do
    expect(repository.endpoints.to_s).to eq File.join(base, 'endpoints')
  end

  it 'return releases path of a endpoint' do
    expect(repository.endpoints['endpoint'].releases.to_s).to eq File.join(base, 'endpoints', 'endpoint', 'releases')
  end

  it 'return new release path of a endpoint' do
    expect(repository.endpoints['endpoint'].releases.new('release').to_s).to eq File.join(base, 'endpoints', 'endpoint', 'releases', 'release')

    travel_to Date.parse('2024-01-01') do
      expect(repository.endpoints['endpoint'].releases.new.to_s).to eq File.join(base, 'endpoints', 'endpoint', 'releases', '20240101')
    end
  end

  it 'return current release path of a endpoint' do
    expect(repository.endpoints['endpoint'].releases.current.to_s).to eq File.join(base, 'endpoints', 'endpoint', 'releases', 'current')
  end

  it 'return working path of a endpoint' do
    expect(repository.endpoints['endpoint'].working.to_s).to eq File.join(base, 'endpoints', 'endpoint', 'working')
  end
end
