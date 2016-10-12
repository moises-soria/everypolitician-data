require 'everypolitician'
require 'json'

module Task
  class RebuildCountriesJSON
    def initialize(to_build = 'data')
      @to_build = to_build
    end

    def execute
      countries = EveryPolitician.countries.select do |c|
        c.slug.downcase.include? to_build.downcase
      end

      data = json_load('countries.json') rescue {}
      # If we know we'll need data for every country directory anyway,
      # it's much faster to pass the single directory 'data' than a list
      # of every country directory:
      commit_metadata = file_to_commit_metadata(
        to_build == 'data' ?
          ['data'] :
          countries.flat_map(&:legislatures).map { |l| 'data/' + l.directory }
      )

      countries.each do |c|
        country = Everypolitician::Country::Metadata.new(
          # TODO: change this to accept an EveryPolitician::Country
          country: c.name,
          dirs: c.legislatures.map { |l| 'data/' + l.directory },
          commit_metadata: commit_metadata,
        ).stanza
        data[data.find_index { |c| c[:name] == country[:name] }] = country
      end
      File.write('countries.json', JSON.pretty_generate(data.sort_by { |c| c[:name] }.to_a))
    end

    private

    attr_reader :to_build
  end
end
