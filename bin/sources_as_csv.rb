require 'everypolitician'
require 'everypolitician/popolo'
require 'csv_to_popolo'
require 'pry'
require 'csv'

def csv_contains_header(csv, heading)
  return true if csv.headers.include?(heading)
  model = Popolo::MODEL[heading]
  return false if model.nil? || model[:aliases].nil?
  return csv.headers.any? { |h| model[:aliases].include?(h) }
end

sources = []
EveryPolitician::Index.new.countries.map do |c|
  c.legislatures.map do |l|
    legislature_sources_dir = File.join(File.dirname(l.raw_data[:sources_directory]), 'sources');
    instructions_file = File.join(legislature_sources_dir, 'instructions.json')
    begin
      JSON.parse(open(instructions_file).read, symbolize_names: true)[:sources].map do |s|
        next if s[:source].nil?
        csv_file = File.join(legislature_sources_dir, s[:file])
        raise "No source file for #{l.country.name}/#{l.name}" unless File.exist? csv_file
        csv = CSV.table(csv_file)
        data = {
          country:      c.name,
          legislature:  l.name,
          type:         s[:type],
          source:       s[:source],
          file:         s[:file],
          identifiers:  csv.headers.select {|h| h.to_s.start_with?('identifier__')}.count,
          dates:        csv_contains_header(csv, :start_date) ||
                        csv_contains_header(csv, :end_date),
        }
        %i(name email twitter facebook phone birth_date group area image).map do |h|
          data[h] = csv_contains_header(csv, h)
        end
        data[:ep_web_url] = "http://everypolitician.org/#{c.slug.downcase}/"
        sources << data
      end
    rescue JSON::ParserError # hit one bad JSON file, didn't want to abort
      next
    end
  end
end
puts sources.first.keys.to_csv
sources.map {|m| puts m.values.to_csv }

