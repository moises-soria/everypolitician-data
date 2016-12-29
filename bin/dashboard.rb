require 'everypolitician'
require 'everypolitician/popolo'
require 'pry'
require 'csv'

# Report some statistics for each legislature
#
# Usage: This should be passed the location of a file
# that ranks the countries (e.g. output from Google Analytics)

(analytics_file = ARGV.first) || abort("Usage: #{$PROGRAM_NAME} <analytics.csv>")
drilldown = CSV.table(analytics_file)
ordering = drilldown.reject { |r| r.count < 5 }.
  select { |r| (r[0].to_s.length > 1) && (r[0][0] == r[0][-1])
}.each_with_index.map { |r, i| [r[0].delete('/'), i] }.to_h

EveryPolitician.countries_json = 'countries.json'

data = EveryPolitician::Index.new.countries.map(&:lower_house).map do |l|
  statsfile = File.join(File.dirname(l.raw_data[:popolo]), 'unstable/stats.json')
  raise "No statsfile for #{l.country.name}/#{l.name}" unless File.exist? statsfile
  stats = JSON.parse(open(statsfile).read, symbolize_names: true)

  now = DateTime.now.to_date
  last_build = Time.at(l.lastmod.to_i).to_date

  latest = stats[:people][:latest_term]
  {
    posn:                (ordering[l.country.slug.downcase] || 999) + 1,
    country:             l.country.name,
    legislature:         l.name,
    lastmod:             last_build.to_s,
    ago:                 (now - last_build).to_i,
    people:              stats[:people][:count],
    wikidata:            stats[:people][:wikidata],
    parties:             stats[:groups][:count],
    wd_parties:          stats[:groups][:wikidata],
    terms:               l.legislative_periods.count,
    wd_terms:            stats[:terms][:wikidata],
    elections:           stats[:elections][:count],
    latest_term:         l.legislative_periods.first.raw_data[:start_date],
    latest_election:     stats[:elections][:latest],
    email:               latest[:contacts][:email].to_f / latest[:count].to_f,
    twitter:             latest[:contacts][:twitter].to_f / latest[:count].to_f,
    facebook:            latest[:contacts][:facebook].to_f / latest[:count].to_f,
    cabinet:             stats[:positions][:cabinet],
  }
end.flatten

puts data.first.keys.to_csv
data.sort_by { |h| [h[:posn], h[:country]] }.each do |h|
  puts h.values.to_csv
end
