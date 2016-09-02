#-----------------------------------------------------------------------
# Update the `stats.json` file for a Legislature
#-----------------------------------------------------------------------

class StatsFile

  def initialize(popolo:)
    @popolo = popolo
  end

  def stats
    now = DateTime.now.to_date

    events = popolo.events
    terms = events.where(classification: 'legislative period')
    elections = events.where(classification: 'general election')

    parties = popolo.organizations.where(classification: 'party').reject { |o| o.name.downcase == 'unknown' }
    wd_part = parties.partition { |p| p.identifier('wikidata') }

    # Ignore elections that are in the following year, or later
    latest_election = elections.map(&:end_date).compact.sort_by { |d| "#{d}-12-31" }.select { |d| d[0...4].to_i <= now.year }.last rescue ''
    latest_term_start = terms.last.start_date rescue ''

    if POSITION_FILTER.file?
      posns = JSON.parse(POSITION_FILTER.read, symbolize_names: true)
      cabinet_positions = posns[:include][:cabinet].count rescue 0
    else
      cabinet_positions = 0
    end

    stats = {
      people:    {
        count:    popolo.persons.count,
        wikidata: popolo.persons.partition { |p| (p[:identifiers] || []).find { |i| i[:scheme] == 'wikidata' } }.first.count,
      },
      groups:    {
        count:    parties.count,
        wikidata: wd_part.first.count,
      },
      terms:     {
        count:  terms.count,
        latest: latest_term_start,
      },
      elections: {
        count:  elections.count,
        latest: latest_election || '',
      },
      positions: {
        cabinet: cabinet_positions,
      },
    }

  end

  private

  attr_reader :popolo
end

STATSFILE = Pathname.new('unstable/stats.json')

namespace :stats do
  task regenerate: 'ep-popolo-v1.0.json' do
    popolo = Everypolitician::Popolo.read('ep-popolo-v1.0.json')
    stats = StatsFile.new(popolo: popolo).stats

    STATSFILE.dirname.mkpath
    STATSFILE.write(JSON.pretty_generate(stats))
  end
end
