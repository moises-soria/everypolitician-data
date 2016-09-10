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

    # For quicker lookup. TODO: use fast EP::Popolo searches
    people = popolo.persons.group_by(&:id)
    orgs   = popolo.organizations.group_by(&:id)
    terms  = popolo.terms.group_by(&:id)
    areas  = popolo.areas.group_by(&:id)

    data = popolo.memberships.select(&:legislative_period_id).map do |m|
      person = people[m.person_id].first
      group  = orgs[m.on_behalf_of_id].first
      house  = orgs[m.organization_id].first
      term   = terms[m.legislative_period_id].first

      {
        id:         person.id.split('/').last,
        name:       person.name_at(m.end_date || term.end_date),
        sort_name:  person.sort_name,
        email:      person.email,
        twitter:    person.twitter,
        facebook:   tidy_facebook_link(person.facebook),
        group:      group.name,
        group_id:   group.id.split('/').last,
        area_id:    m.area_id,
        area:       m.area_id && areas[m.area_id].first.name,
        chamber:    house.name,
        term:       term.id.split('/').last,
        start_date: m.start_date,
        end_date:   m.end_date,
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

    # Write positions.csv
    csv_headers = %w(id name position start_date end_date type).to_csv
    csv_data = all_positions.select { |posn| position_map.include_ids.include? posn.id }.map do |posn|
      [posn.person.id, posn.person.name, posn.label, posn.start_date, posn.end_date, position_map.type(posn.id)].to_csv
    end

    POSITION_CSV.dirname.mkpath
    POSITION_CSV.write(csv_headers + csv_data.join)

    # Warn about Cabinet members missing dates
    all_positions.select  { |posn| position_map.cabinet_ids.include? posn.id }
                 .select  { |posn| posn.start_date.to_s.empty? && posn.end_date.to_s.empty? }
                 .sort_by(&:label)
                 .each do |posn|
      warn "  ☇ No dates for #{posn.person.name} (#{posn.person.wikidata}) as #{posn.label}"
    end

    # Warn about unknown positions
    unknown_posns = all_positions.reject { |p| position_map.known_ids.include?(p.id) }
    grouped_posns = unknown_posns.group_by(&:id)
    grouped_posns.sort_by { |_, ups| ups.count }.each do |id, ups|
      warn "  Unknown position (x#{ups.count}): #{id} #{ups.first.label} — e.g. #{ups.first.person.wikidata}"
    end

    # Rebuild the position filter, with counts on unknowns
    new_map = position_map.to_json
    unknown = grouped_posns.sort_by { |_, us| us.first.label.to_s }.map do |id, us|
      {
        id:          id,
        name:        us.first.label,
        description: us.first.description,
        count:       us.count,
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
