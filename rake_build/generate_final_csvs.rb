require_relative '../lib/position_filterer'
require 'everypolitician/popolo'
require 'json5'

desc 'Build the term-table CSVs'
task csvs: ['term_csvs:term_tables', 'term_csvs:name_list', 'term_csvs:positions', 'term_csvs:reports']

CLEAN.include('term-*.csv', 'names.csv')

namespace :term_csvs do
  def tidy_facebook_link(page)
    # CSV-to-Popolo runs these through FacebookUsernameExtractor, so
    # we can just strip off the prefix
    return if page.to_s.empty?
    page.sub('https://facebook.com/', '')
  end

  require 'csv'
  desc 'Generate the Term Tables'
  task term_tables: 'ep-popolo-v1.0.json' do
    @json = JSON.parse(File.read('ep-popolo-v1.0.json'), symbolize_names: true)
    @popolo = popolo = EveryPolitician::Popolo.read('ep-popolo-v1.0.json')
    people = Hash[popolo.persons.map { |p| [p.id, p] }]
    term_end_dates = Hash[popolo.terms.map { |t| [t.id, t.end_date] }]

    data = @json[:memberships].select { |m| m.key? :legislative_period_id }.map do |m|
      person = people[m[:person_id]]
      group  = @json[:organizations].find { |o| (o[:id] == m[:on_behalf_of_id]) || (o[:id].end_with? "/#{m[:on_behalf_of_id]}") }
      house  = @json[:organizations].find { |o| (o[:id] == m[:organization_id]) || (o[:id].end_with? "/#{m[:organization_id]}") }

      if group.nil?
        warn "No group for #{m}"
        binding.pry
        next
      end

      {
        id:         person.id.split('/').last,
        name:       person.name_at(m[:end_date] || term_end_dates[m[:legislative_period_id]]),
        sort_name:  person.sort_name,
        email:      person.email,
        twitter:    person.twitter,
        facebook:   tidy_facebook_link(person.facebook),
        group:      group[:name],
        group_id:   group[:id].split('/').last,
        area_id:    m[:area_id],
        area:       m[:area_id] && @json[:areas].find { |a| a[:id] == m[:area_id] }[:name],
        chamber:    house[:name],
        term:       m[:legislative_period_id].split('/').last,
        start_date: m[:start_date],
        end_date:   m[:end_date],
        image:      person.image,
        gender:     person.gender,
      }
    end

    terms = data.group_by { |r| r[:term] }
    warn "Creating #{terms.count} term file#{terms.count > 1 ? 's' : ''}"
    terms.each do |t, rs|
      filename = "term-#{t}.csv"
      header = rs.first.keys.to_csv
      rows   = rs.portable_sort_by { |r| [r[:name], r[:id], r[:start_date].to_s, r[:area].to_s] }.map { |r| r.values.to_csv }
      csv    = [header, rows].compact.join
      File.write(filename, csv)
    end
  end

  task top_identifiers: :term_tables do
    top_identifiers = @json[:persons].map { |p| (p[:identifiers] || []).map { |i| i[:scheme] } }.flatten
                                     .reject { |i| i == 'everypolitician_legacy' }
                                     .group_by { |i| i }
                                     .sort_by { |_i, is| -is.count }
                                     .take(5)
                                     .map { |i, is| [i, is.count] }

    if top_identifiers.any?
      warn "\nTop identifiers:"
      top_identifiers.each do |i, c|
        warn "  #{c} x #{i}"
      end
      warn "\n"
    end
  end

  task name_list: :top_identifiers do
    names = @json[:persons].flat_map do |p|
      nameset = Set.new([p[:name]])
      nameset.merge (p[:other_names] || []).map { |n| n[:name] }
      nameset.map { |n| [n, p[:id].split('/').last] }
    end.uniq { |name, id| [name.downcase, id] }.sort_by { |name, id| [name.downcase, id] }

    filename = 'names.csv'
    header = %w(name id).to_csv
    csv    = [header, names.map(&:to_csv)].compact.join
    warn "Creating #{filename}"
    File.write(filename, csv)
  end

  desc 'Add some final reporting information'
  task reports: :term_tables do
    wikidata_persons = @json[:persons].partition { |p| (p[:identifiers] || []).find { |i| i[:scheme] == 'wikidata' } }
    wikidata_parties = @json[:organizations].select { |o| o[:classification] == 'party' }
                                            .reject { |p| p[:name].downcase == 'unknown' }
                                            .partition do |p|
      (p[:identifiers] || []).find { |i| i[:scheme] == 'wikidata' }
    end
    matched, unmatched = wikidata_persons.map(&:count)
    warn "Persons matched to Wikidata: #{matched} ✓ #{unmatched.zero? ? '' : "| #{unmatched} ✘"}"
    wikidata_persons.last.shuffle.take(10).each { |p| warn "  No wikidata: #{p[:name]} (#{p[:id]})" } unless matched.zero?

    matched, unmatched = wikidata_parties.map(&:count)
    warn "Parties matched to Wikidata: #{matched} ✓ #{unmatched.zero? ? '' : "| #{unmatched} ✘"}"
    wikidata_parties.last.shuffle.take(5).each { |p| warn "  No wikidata: #{p[:name]} (#{p[:id]})" } unless matched.zero?
  end

  # TODO: move this to its own file
  class PositionMap
    # Which Wikidata Positions we're interested in, and how to group them

    def initialize(pathname:)
      @pathname = pathname
    end

    def to_json
      return empty_filter unless pathname.exist?
      raw_json
    end

    def include_ids
      to_json[:include].values.flatten.map { |p| p[:id] }.to_set
    end

    def exclude_ids
      to_json[:exclude].values.flatten.map { |p| p[:id] }.to_set
    end

    def known_ids
      include_ids + exclude_ids
    end

    def cabinet_ids
      (to_json[:include][:cabinet] || []).map { |p| p[:id] }.to_set
    end

    private

    attr_reader :pathname

    def empty_filter
      { exclude: { self: [], other: [] }, include: { self: [], other_legislatures: [], cabinet: [], executive: [], party: [], other: [] } }
    end

    def raw_json
      @json ||= json5_parse(pathname.read).each do |_s, fs|
        fs.each { |_, fs| fs.each { |f| f.delete :count } }
      end
    end

    # TODO: move this to somewhere more generally useful
    def json5_parse(data)
      # read with JSON5 to be more liberal about trailing commas.
      # But that doesn't have a 'symbolize_names' so rountrip through JSON
      JSON.parse(JSON5.parse(data).to_json, symbolize_names: true)
    end
  end

  class WikidataPositionFile
    def initialize(pathname:)
      @pathname = pathname
    end

    def positions_for(person)
      json[person.wikidata.to_sym].to_a.map do |posn|
        WikidataPosition.new(raw: posn, person: person)
      end
    end

    def json
      JSON.parse(pathname.read, symbolize_names: true)
    end

    private

    attr_reader :pathname
  end


  class WikidataPosition
    attr_reader :person
    def initialize(raw:, person:)
      @raw = raw
      @person = person
    end

    def id
      raw[:id]
    end

    def label
      raw[:label]
    end

    def description
      raw[:description]
    end

    def start_date
      qualifier(580)
    end

    def end_date
      qualifier(582)
    end

    private

    attr_reader :raw

    def qualifiers
      raw[:qualifiers] || {}
    end

    def qualifier(pcode)
      qualifiers["P#{pcode}".to_sym]
    end
  end


  desc 'Build the Positions file'
  task positions: ['ep-popolo-v1.0.json'] do
    next unless POSITION_RAW.file?
    warn "Creating #{POSITION_CSV}"
    p39s = WikidataPositionFile.new(pathname: POSITION_RAW)
    position_map = PositionMap.new(pathname: POSITION_FILTER)

    people_with_wikidata = @popolo.persons.select(&:wikidata)
    all_positions = people_with_wikidata.flat_map do |p|
      p39s.positions_for(p)
    end

    csv_headers = %w(id name position start_date end_date).to_csv
    csv_data = all_positions.select { |posn| position_map.include_ids.include? posn.id }.map do |posn|
      [posn.person.id, posn.person.name, posn.label, posn.start_date, posn.end_date].to_csv
    end

    POSITION_CSV.dirname.mkpath
    POSITION_CSV.write(csv_headers + csv_data.join)

    # ------------------------------------------------------------------
    # Warn about Cabinet members missing dates
    # TODO: move elsewhere
    # want.select { |p| position_map.cabinet_ids.include? p[:position_id] }.select { |p| p[:start_date].nil? && p[:end_date].nil? }.each do |p|
      # warn "  ☇ No dates for #{p[:name]} (#{p[:wikidata]}) as #{p[:position]}"
    # end

    # Warn about unknown positions
    unknown_posns = all_positions.reject { |p| position_map.known_ids.include?(p.id) }
    unknown_posns.group_by(&:id).sort_by { |_, ups| ups.count }.each do |id, ups|
      warn "  Unknown position (x#{ups.count}): #{id} #{ups.first.label} — e.g. #{ups.first.person.wikidata}"
    end

    # Rebuild the position filter, with counts on unknowns
    new_map = position_map.to_json
    unknown = unknown_posns.group_by(&:id).sort_by { |_, us| us.first.label }.map do |id, us|
      {
        id: id,
        name: us.first.label,
        description: us.first.description,
        count: us.count
      }
    end
    (new_map[:unknown] ||= {})[:unknown] = unknown
    POSITION_FILTER.write(JSON.pretty_generate(new_map))

    if unknown && ENV['GENERATE_POSITION_INTERFACE']
      html = Position::Filter::HTML.new(new_map).html
      POSITION_HTML.write(html)
      FileUtils.copy('../../../templates/position-filter.js', 'sources/manual/.position-filter.js')
      warn "open #{POSITION_HTML}".yellow
      warn "pbpaste | bundle exec ruby #{POSITION_LEARNER} #{POSITION_FILTER}".yellow
    end
  end
end
