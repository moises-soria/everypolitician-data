#-----------------------------------------------------------------------
# Update the `stats.json` file for a Legislature
#-----------------------------------------------------------------------

class StatsFile

  def initialize(popolo:)
    @popolo = popolo
  end

  def stats

    latest_term_start = terms.last.start_date rescue ''

    stats = {
      people:    {
        count:    people.count,
        wikidata: people_wikidata_partition.first.count,
      },
      groups:    {
        count:    known_parties.count,
        wikidata: party_wikidata_partition.first.count,
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

  def now
    DateTime.now.to_date
  end

  def people
    popolo.persons
  end

  def people_wikidata_partition
    people.partition { |p| p.identifier('wikidata') }
  end

  def events
    popolo.events
  end

  def terms
    events.where(classification: 'legislative period')
  end

  def elections
    events.where(classification: 'general election')
  end

  def known_parties
    popolo.organizations.where(classification: 'party').reject { |o| o.name.downcase == 'unknown' }
  end

  def party_wikidata_partition
    known_parties.partition { |p| p.identifier('wikidata') }
  end

  def latest_election
    # Ignore elections that are in the following year, or later
    elections.map(&:end_date).compact.sort_by { |d| "#{d}-12-31" }.select { |d| d[0...4].to_i <= now.year }.last rescue ''
  end

  def cabinet_positions
    return 0 unless POSITION_FILTER.file?
    posns = JSON.parse(POSITION_FILTER.read, symbolize_names: true)
    posns[:include][:cabinet].count rescue 0
  end
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
