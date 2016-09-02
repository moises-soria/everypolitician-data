#-----------------------------------------------------------------------
# Update the `stats.json` file for a Legislature
#-----------------------------------------------------------------------
class StatsFile
  # @param popolo [EveryPolitician::Popolo]
  # @param position_filter [Pathname]
  def initialize(popolo:, position_filter:)
    @popolo = popolo
    @position_filter = position_filter
  end

  # Re-generated statistics for this legislature
  # @return [Hash]
  def stats
    {
      people:    people_stats,
      groups:    group_stats,
      terms:     term_stats,
      elections: election_stats,
      positions: position_stats,

    }
  end

  private

  attr_reader :popolo, :position_filter

  def people_stats
    {
      count:    people.count,
      wikidata: people_wikidata_partition.first.count,
    }
  end

  def group_stats
    {
      count:    known_parties.count,
      wikidata: party_wikidata_partition.first.count,
    }
  end

  def term_stats
    {
      count:  terms.count,
      latest: latest_term_start,
    }
  end

  def election_stats
    {
      count:  elections.count,
      latest: latest_election || '',
    }
  end

  def position_stats
    {
      cabinet: cabinet_positions,
    }
  end

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

  def latest_term_start
    terms.last.start_date rescue ''
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
    return 0 unless position_filter.file?
    posns = JSON.parse(position_filter.read, symbolize_names: true)
    posns[:include][:cabinet].count rescue 0
  end
end

STATSFILE = Pathname.new('unstable/stats.json')

namespace :stats do
  task regenerate: 'ep-popolo-v1.0.json' do
    popolo = Everypolitician::Popolo.read('ep-popolo-v1.0.json')
    stats = StatsFile.new(popolo: popolo, position_filter: POSITION_FILTER).stats

    STATSFILE.dirname.mkpath
    STATSFILE.write(JSON.pretty_generate(stats))
  end
end
