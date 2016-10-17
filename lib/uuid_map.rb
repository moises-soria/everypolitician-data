require 'csv'
require 'rcsv'

# Encapsulates the 'data-ids' files that tie
# incoming source IDs to our UUIDs
#
# We're in the process of moving the location of those files, so for
# this currently checks _both_ locations for reading, but always writes
# back out to the new location
#
# TODO: Add the 'give me a new UUID' logic here

class UuidMapFile
  def initialize(pathname)
    @pathname = pathname
  end

  def mapping
    @mapping ||= raw_csv.map { |r| [r['id'], r['uuid']] }.to_h
  end

  def id_for(uuid)
    mapping.key(uuid)
  end

  def uuid_for(id)
    mapping[id]
  end

  def rewrite(data)
    @mapping = nil
    pathname.parent.mkpath
    ::CSV.open(pathname, 'w') do |csv|
      csv << %i(id uuid)
      data.each { |id, uuid| csv << [id, uuid] }
    end
  end

  def remap(from, to)
    if uuid_for(from) && !uuid_for(to)
      mapping[to] = mapping.delete(from)
      rewrite(mapping)
    end
  end

  private

  attr_reader :pathname

  def raw_csv
    return {} unless pathname.exist?
    return {} if (raw = pathname.read).empty?
    Rcsv.parse(raw, row_as_hash: true, columns: {})
  end
end
