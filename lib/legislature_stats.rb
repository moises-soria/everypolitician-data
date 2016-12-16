
class StatsFile
  # Generates stats on the data we hold for a Legislature
  #
  # This class generates a simple Hash of data, suitable for serialising
  # as JSON and writing out to the `stats.json` for that house.

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
    current = popolo.latest_term.memberships.map(&:person).uniq
    {
      count:       people.count,
      wikidata:    people_wikidata_partition.first.count,
      latest_term: {
        count:    current.count,
        contacts: {
          email:    current.select(&:email).count,
          facebook: current.select(&:facebook).count,
          twitter:  current.select(&:twitter).count,
        },
      },
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
      count:  popolo.terms.count,
      latest: popolo.latest_term.start_date,
    }
  end

  def election_stats
    {
      count:  popolo.elections.count,
      latest: latest_election_date || '',
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
    people.partition(&:wikidata)
  end

  def known_parties
    popolo.organizations.where(classification: 'party').reject { |o| o.name.downcase == 'unknown' }
  end

  def party_wikidata_partition
    known_parties.partition(&:wikidata) rescue binding.pry
  end

  def latest_election_date
    # Ignore elections that are in the following year, or later
    popolo.elections.map(&:end_date).compact.sort_by { |d| "#{d}-12-31" }.select { |d| d[0...4].to_i <= now.year }.last rescue ''
  end

  def cabinet_positions
    return 0 unless position_filter.file?
    posns = JSON.parse(position_filter.read, symbolize_names: true)
    posns[:include][:cabinet].count rescue 0
  end
end
